import requests
import sys
sys.stdout.reconfigure(encoding='utf-8')

URL = "https://api-v3.thaiwater.net/api/v1/thaiwater30/provinces/dam?province_id=50"

def get_dams():
    res = requests.get(URL)
    data = res.json()["data"]

    targets = ["แม่จอกหลวง", "แม่งัดสมบูรณ์ชล"]

    result = []

    # loop through all 3 sections
    for section in ["dam_hourly", "dam_medium", "dam_daily"]:
        for item in data.get(section, []):
            name = item.get("dam", {}).get("dam_name", {}).get("th", "")

            if any(t in name for t in targets):
                result.append({
                    "name": name,
                    "storage": item.get("dam_storage"),
                    "percent": item.get("dam_storage_percent"),
                    "inflow": item.get("dam_inflow"),
                    "released": item.get("dam_released"),
                    "date": item.get("dam_date")
                })
    
    return result

def get_dam_released():
    res = requests.get(URL)
    data = res.json()["data"]

    targets = ["แม่จอกหลวง", "แม่งัดสมบูรณ์ชล"]

    result = []

    # loop through all 3 sections
    for section in ["dam_hourly", "dam_medium", "dam_daily"]:
        for item in data.get(section, []):
            name = item.get("dam", {}).get("dam_name", {}).get("th", "")

            if any(t in name for t in targets):
                if (item.get("dam_released")==None): result.append(0)
                else: result.append(item.get("dam_released"))
    
    return result