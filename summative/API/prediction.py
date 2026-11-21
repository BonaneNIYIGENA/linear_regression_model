from datetime import datetime
from pathlib import Path
from typing import Literal

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI
from pydantic import BaseModel, Field, field_validator

FOLDER = Path(__file__).parent
MODEL_PATH = FOLDER / "best_model.pkl"

FEATURES = ["age", "sex", "province", "area", "school_level", "school_type", "boarding", "household_size", "payer"]

# the allowed text for every category column, exactly as in the training data
CHOICES = {
    "sex": ["Male", "Female"],
    "province": ["Kigali", "Southern", "Western", "Northern", "Eastern"],
    "area": ["Urban", "Rural"],
    "school_level": ["ECD", "Nursery", "Primary", "Lower secondary", "Upper secondary", "Tertiary"],
    "school_type": ["Public", "Private", "Government subsidized"],
    "boarding": ["Yes", "No", "Not applicable"],
    "payer": ["Father", "Mother", "Both parents", "Other household member", "Other relative", "Self", "Other"],
}


class Student(BaseModel):
    age: int = Field(ge=0, le=60, description="age in years")
    sex: Literal["Male", "Female"]
    province: Literal["Kigali", "Southern", "Western", "Northern", "Eastern"]
    area: Literal["Urban", "Rural"]
    school_level: Literal["ECD", "Nursery", "Primary", "Lower secondary", "Upper secondary", "Tertiary"]
    school_type: Literal["Public", "Private", "Government subsidized"]
    boarding: Literal["Yes", "No", "Not applicable"]
    household_size: int = Field(ge=1, le=20, description="number of people in the household")
    payer: Literal["Father", "Mother", "Both parents", "Other household member", "Other relative", "Self", "Other"]

    # "private" and "Private " are accepted as "Private"
    @field_validator(*CHOICES, mode="before")
    @classmethod
    def match_capital_letters(cls, value, info):
        if isinstance(value, str):
            for choice in CHOICES[info.field_name]:
                if value.strip().lower() == choice.lower():
                    return choice
        return value


app = FastAPI(title="Schooling expenditure prediction", description="Predicts the yearly school spending of a student in RWF")

model = joblib.load(MODEL_PATH)   # loaded once when the server starts
model.steps[-1][1].set_params(n_jobs=1)   # one thread is faster for a single row and fits the free Render plan


@app.get("/")
def home():
    return {"message": "Schooling expenditure API. Open /docs to try it."}


@app.post("/predict")
def predict(student: Student):
    started = datetime.now()
    row = pd.DataFrame([student.model_dump()])[FEATURES]
    log_prediction = model.predict(row)[0]
    finished = datetime.now()
    return {
        "predicted_expenditure_rwf": round(float(np.expm1(log_prediction))),
        "started_at": started.strftime("%H:%M:%S.%f")[:-3],
        "finished_at": finished.strftime("%H:%M:%S.%f")[:-3],
        "time_ms": round((finished - started).total_seconds() * 1000, 1),
    }
