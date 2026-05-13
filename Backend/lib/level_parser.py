from datetime import datetime
from lib.rain_parser import get_rainfall_box
from lib.dam_parser import get_dam_released

import requests
import json
import re


BASE_URL = "https://hydro1.ddns.net/main/information_4/houly/water_today_json.php"


def strip_jsonp(text):
    text = text.strip()

    # Case: already JSON
    if text.startswith("[") or text.startswith("{"):
        return text

    # Case: JSONP
    match = re.search(r"\((.*)\)", text, re.DOTALL)
    if match:
        return match.group(1)

    # fallback (bad response)
    raise ValueError("Invalid API response (not JSON/JSONP): " + text[:200])

# def fetch_raw_data(st1, st2, date_ddmmyyyy):
#     params = {
#         "station_id1": f"P.{st1}",
#         "station_id2": f"P.{st2}",
#         "date": date_ddmmyyyy
#     }

#     res = requests.get(BASE_URL, params=params)
#     text = res.text
    
#     if res.status_code != 200:
#         raise ValueError(f"API error: {res.status_code}")
    
#     if not text or len(text.strip()) == 0:
#         raise ValueError("Empty response from API")

#     json_str = strip_jsonp(text)
#     return json.loads(json_str)

def fetch_raw_data_with_params(params):
    res = requests.get(BASE_URL, params=params)

    if res.status_code != 200:
        raise ValueError(f"API error: {res.status_code}")

    text = res.text.strip()

    if not text:
        raise ValueError("Empty response")

    json_str = strip_jsonp(text)
    data = json.loads(json_str)

    if isinstance(data, dict):
        data = [data]

    return data

def extract_hours(obj, prefix, day, suffix=""):
    values = []

    for i in range(1, 25):
        key_c = f"{prefix}{i}_day{day}{suffix}_c"
        key = f"{prefix}{i}_day{day}{suffix}"

        val = obj.get(key_c, obj.get(key))

        if val in (0,"", None):
            # values.append(None)
            continue
        else:
            values.append(float(val))

    return values

def clean_date(obj):
    thai_months = {
        "มกราคม": "01",
        "กุมภาพันธ์": "02",
        "มีนาคม": "03",
        "เมษายน": "04",
        "พฤษภาคม": "05",
        "มิถุนายน": "06",
        "กรกฎาคม": "07",
        "สิงหาคม": "08",
        "กันยายน": "09",
        "ตุลาคม": "10",
        "พฤศจิกายน": "11",
        "ธันวาคม": "12"
    }
    
    match = re.search(r"(\d+)\s+(\S+)\s+(\d+)", obj)
    if not match:
        return None

    day, month_th, year_be = match.groups()

    day = day.zfill(2)
    month = thai_months.get(month_th, "00")
    year = str(int(year_be) - 543)  # BE → AD

    return f"{day}-{month}-{year}"

def parse_station(obj, station_num):
    days = []

    suffix = "" if station_num == 1 else "_2"

    for day in range(1, 4):
        level = extract_hours(obj, "level", day, suffix)
        discharge = extract_hours(obj, "dischg", day, suffix)

        if not level and not discharge:
            continue

        date_key = f"date_day{day}" if station_num == 1 else f"date_day{day}_2"

        days.append({
            "date": clean_date(obj.get(date_key)),
            "level": level,
            "discharge": discharge
        })

    return days

def safe_float(val):
    try:
        return float(val)
    except (TypeError, ValueError):
        return None

def parse_station_block(obj, n):
    sid = obj.get(f"station_id{n}")
    if not sid:
        return None

    level_limit = obj.get(f"level_limit{n}_day1")
    dischg_limit = obj.get(f"dischg_limit{n}_day1")

    address = obj.get(f"Address_{n}")

    return {
        "station_id": sid,
        "address": address,
        "limits": {
            "level_m": safe_float(level_limit),
            "discharge_m3s": safe_float(dischg_limit),
        },
        "days": parse_station(obj, n)
    }

def clean_data(raw):
    results = []

    for obj in raw:
        if not obj:
            continue

        # ✅ extract station 1 if exists
        if obj.get("station_id1"):
            results.append(parse_station_block(obj, 1))

        # ✅ extract station 2 if exists
        if obj.get("station_id2"):
            results.append(parse_station_block(obj, 2))

    return results

def get_multi_station_data(stations, date):
    results = []

    # process in pairs of 2
    for i in range(0, len(stations), 2):
        f = False
        st1 = f"P.{stations[i]}"
        if i+1 < len(stations):
            st2 = f"P.{stations[i+1]}"
            if (st1==st2):
                params = {
                    "station_id1": "",
                    "station_id2": st1,
                    "date": date
                }
                f = True
            else:
                params = {
                    "station_id1": st1,
                    "station_id2": st2,
                    "date": date
                }
        else:
            params = {
                "station_id1": "",
                "station_id2": st1,
                "date": date
            }
            
        raw = fetch_raw_data_with_params(params)
        cleaned = clean_data(raw)
        if f:
            results.extend(cleaned)
        results.extend(cleaned)

    return results

def get_level(station, date):
    res = get_multi_station_data(station, date);
    
    for item in res:
        for day in item["days"]:
            last = -1000;
            for level in day["level"]:
                if level == None: break;
                last = level;
            if last == -1000:
                continue
            else: return last
            
def get_last_24_valid_levels(stations, date):
    res = get_multi_station_data(stations, date)
    
    to_return = []
    last_updated = []

    for item in res:
        all_valid_levels = []
        f = True
        # 2. Iterate through Day 1, Day 2, and Day 3[cite: 7]
        # These are usually ordered from Today (Day 1) back to Day 3
        # However, we want to collect them in chronological order: 
        # Day 3 -> Day 2 -> Day 1
        for day in item["days"]:
            # Filter out None or empty values for each day[cite: 7]
            valid_day_levels = [val for val in reversed(day["level"]) if val is not None]
            all_valid_levels.extend(reversed(valid_day_levels))
            if f:
                last_updated.append(len(all_valid_levels))
                f=False
            if len(all_valid_levels) >= 24:
                to_return.append(all_valid_levels[-24:])
                break;

    return [to_return,last_updated]

def get_last_24_valid_discharge(stations, date):
    res = get_multi_station_data(stations, date)
    
    to_return = []
    last_updated = []

    for item in res:
        all_valid_levels = []
        f = True;
        # 2. Iterate through Day 1, Day 2, and Day 3[cite: 7]
        # These are usually ordered from Today (Day 1) back to Day 3
        # However, we want to collect them in chronological order: 
        # Day 3 -> Day 2 -> Day 1
        for day in reversed(item["days"]):
            # Filter out None or empty values for each day[cite: 7]
            valid_day_levels = [val for val in day["discharge"] if val is not None]
            all_valid_levels.extend(valid_day_levels)
            if f:
                last_updated.append(len(all_valid_levels))
                f=False
            if len(all_valid_levels) >= 24:
                to_return.append(all_valid_levels[-24:])
                break;

    return [to_return,last_updated]

def get_discharge_delta(rain = False, dam = False):
    res = get_last_24_valid_discharge(['67','1'], datetime.now().strftime("%d-%m-%Y"))[0]
    rainfall=0
    dam_discharge=0
    if rain: rainfall = get_rainfall_box(18.786961, 99.005089, 19.00977, 98.95978)*(30/24);
    if dam: dam_discharge = get_dam_released()[0]*(11.67/24)
    to_return = []
    for i in range(24):
        to_return.append(((res[0][i]+rainfall+dam_discharge))-(res[1][i]))
        
    return to_return

def get_discharge_delta_all():
    res = get_last_24_valid_discharge(['67','1'], datetime.now().strftime("%d-%m-%Y"))[0]
    rainfall = max(get_rainfall_box(18.786961, 99.005089, 19.00977, 98.95978)-5,0)*30/24;
    dam_discharge = 0;
    try:
        dam_discharge = get_dam_released()[0]*(11.67/24)
    except:
        print("")
    to_return = [[],[],[]]
    for i in range(24):
        to_return[0].append(((res[0][i]))-(res[1][i]))
        to_return[1].append(((res[0][i]+rainfall))-(res[1][i]))
        to_return[2].append(((res[0][i]+rainfall+dam_discharge))-(res[1][i]))
        
    return to_return


def level_status(threshold, date = datetime.now().strftime("%d-%m-%Y")):
    level = get_level(['1'], date);
    to_return = ""
    if level >= threshold*1.5:
        to_return = "น้ำท่วมสูงมาก"
    elif level >= threshold*1.25:
        to_return = "น้ำท่วมสูง"
    elif level >= threshold*1.05:
        to_return = "น้ำท่วม"
    elif level >= threshold:
        to_return = "สูงกว่าตลิ่ง"
    elif level >= threshold*0.9:
        to_return = "สูง"
    elif level >= threshold*0.8:
        to_return = "ค่อนข้างสูง"
    elif level <= 0.5:
        to_return = "น้ำแห้ง"
    else: to_return = "ปกติ"
    return to_return