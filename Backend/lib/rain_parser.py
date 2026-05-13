import requests
import sys
sys.stdout.reconfigure(encoding='utf-8')

URL = "https://api-v3.thaiwater.net/api/v1/thaiwater30/provinces/rain24?include_zero=1&province_code=50&basin_code=6"

def get_total_rainfall():
    res = requests.get(URL)
    data = res.json()["data"]

    total_rain = 0

    for item in data:
        rain = item.get("rain_24h", 0)
        total_rain += rain if rain else 0

    return total_rain

def get_rainfall_box(lt1,ln1,lt2,ln2):
    res = requests.get(URL)
    data = res.json()["data"]
    
    st = abs(lt1-lt2)/2
    mid = (ln1+ln2+abs(ln1-ln2))/2

    total_rain = 0

    for item in data:
        if lt1-0.005 <= item.get("station").get("tele_station_lat") <= lt2+0.005 and (item.get("station").get("tele_station_long") <= mid + st or item.get("station").get("tele_station_long") >= mid - st):
            rain = item.get("rain_24h", 0)
            total_rain += rain if rain else 0
        
    return total_rain