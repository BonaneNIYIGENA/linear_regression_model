from datetime import datetime
from pathlib import Path
from typing import Literal

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field, field_validator

from retrain import router

FOLDER = Path(__file__).parent
MODEL_PATH = FOLDER / "best_model.pkl"

FEATURES = ["age", "sex", "province", "area", "school_level", "school_type", "boarding", "household_size", "payer"]

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
    # strict: "5" or 5.0 is refused for a whole number, and unknown fields are refused
    model_config = ConfigDict(
        strict=True,
        extra="forbid",
        json_schema_extra={"examples": [{
            "age": 5, "sex": "Male", "province": "Kigali", "area": "Urban", "school_level": "Nursery",
            "school_type": "Private", "boarding": "Not applicable", "household_size": 6, "payer": "Father",
        }]},
    )

    age: int = Field(ge=0, le=60, description="age in years")
    sex: Literal["Male", "Female"]
    province: Literal["Kigali", "Southern", "Western", "Northern", "Eastern"]
    area: Literal["Urban", "Rural"]
    school_level: Literal["ECD", "Nursery", "Primary", "Lower secondary", "Upper secondary", "Tertiary"]
    school_type: Literal["Public", "Private", "Government subsidized"]
    boarding: Literal["Yes", "No", "Not applicable"] = Field(description="only asked in secondary school")
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


class Prediction(BaseModel):
    predicted_expenditure_rwf: int
    started_at: str
    finished_at: str
    time_ms: float


app = FastAPI(title="Schooling expenditure prediction", description="Predicts the yearly school spending of a student in RWF")

# CORS decides which websites may call this API from a browser.
# Allowed: only my Render site and my local Flutter web address (no "*"), the GET and POST methods
# the routes need, and the Content-Type header that JSON and file uploads need.
# Restricted: every other website, PUT/DELETE, other headers, and credentials (the API has no login).
# The Flutter mobile app is not a browser, so CORS does not apply to it.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://linear-regression-model-h6i6.onrender.com", "http://localhost:5000", "http://127.0.0.1:5000"],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
    allow_credentials=False,
)

app.include_router(router)

model = joblib.load(MODEL_PATH)
model.steps[-1][1].set_params(n_jobs=1)


@app.api_route("/", methods=["GET", "HEAD"])
def home():
    return {"message": "Schooling expenditure API. Open /docs to try it."}


@app.post("/predict", response_model=Prediction)
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
