from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

from lib.level_parser import get_multi_station_data, get_level, get_last_24_valid_levels, level_status, get_discharge_delta, get_discharge_delta_all, get_last_24_valid_discharge
from lib.dam_parser import get_dam_released
from lib.rain_parser import get_total_rainfall, get_rainfall_box
from lib.level_predictor import predict_level, predict_chance

# uvicorn main:app --reload

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "FastAPI is running!"}

@app.get("/water") # up->down 20 75 67 103 1
def water(stations: str = Query(...), date: str = Query(...)):
    station_list = stations.split(",")

    return get_multi_station_data(station_list, date)

@app.get("/water24h") # up->down 20 75 67 103 1
def water24h(stations: str = Query(...), date: str = Query(...)):
    station_list = stations.split(",")

    return get_last_24_valid_levels(station_list, date)

@app.get("/discharge24h") # up->down 20 75 67 103 1
def discharge24h(stations: str = Query(...), date: str = Query(...)):
    station_list = stations.split(",")

    return get_last_24_valid_discharge(station_list, date)

@app.get("/level") # up->down 20 75 67 103 1
def level(station: str, date: str):
    return get_level(station, date)

@app.get("/dam")
def dam():
    return get_dam_released();

@app.get("/rainfall")
def get_rainfall():
    return get_rainfall_box(18.786961, 99.005089, 19.00977, 98.95978);

@app.get("/predict_level") #dd-mm-yyyy
def get_predict_level(date: str = ""): 
    if (date!=""): return predict_level(date);
    return predict_level();

@app.get("/level_status")
def get_level_status(date: str = ""):
    if (date!=""): return level_status(3.7, date);
    return level_status(3.7);

@app.get("/predict_chance")
def get_predict_chance():
    return predict_chance(3.7);

@app.get("/discharge_delta")
def _get_discharge_delta(rain: bool = False, dam: bool = False):
    return get_discharge_delta(rain, dam);

@app.get("/discharge_delta_all")
def _get_discharge_delta_all():
    return get_discharge_delta_all();