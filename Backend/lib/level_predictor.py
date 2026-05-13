from lib.rain_parser import get_rainfall_box
from lib.dam_parser import get_dam_released
from lib.level_parser import get_last_24_valid_discharge, get_level
import statistics
from datetime import datetime

# P.1   	18.786961, 99.005089
# P.103     18.866750, 98.978778
# P.67      19.00977, 98.95978

# P.75      19.12207, 98.94447
# P.20      19.36728, 98.96884

def predict_level(date = datetime.now().strftime("%d-%m-%Y")):
    rain = max(get_rainfall_box(18.786961, 99.005089, 19.00977, 98.95978)-5, 0); # mm
    dam_data = get_dam_released()
    dam_val = dam_data[0] if dam_data else 0 # 10^6 m3
    discharges = get_last_24_valid_discharge(['1','67'], date) # 10^6 m3
    if len(discharges) < 2:
        return get_level(['1'], date)
    net_flow = statistics.mean(discharges[0][1])-statistics.mean(discharges[0][0])+(dam_val*11.67)
    rain_contribution = rain * 0.02
    return get_level(['1'], date)+(net_flow*0.01 + rain_contribution);

def predict_chance(threshold):
    level = predict_level();
    to_return = ""
    if level >= threshold:
        to_return = "สูงมาก"
    elif level >= threshold*0.95:
        to_return = "สูง"
    elif level >= threshold*0.85:
        to_return = "ค่อนข้างสูง"
    elif level >= threshold*0.8:
        to_return = "เฝ้าระวัง"
    else: to_return = "ต่ำ"
    return to_return
