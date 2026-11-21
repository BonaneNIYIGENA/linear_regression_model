from io import BytesIO
from pathlib import Path
import numpy as np
import pandas as pd
from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import ValidationError
from sklearn.base import clone
from sklearn.linear_model import SGDRegressor
import prediction

TRAIN_PATH = Path(__file__).parent / "data" / "train_data.csv"

router = APIRouter()


@router.post("/retrain")
async def retrain(file: UploadFile = File(...)):

    try:
        new_data = pd.read_csv(BytesIO(await file.read()))
    except Exception:
        raise HTTPException(status_code=400, detail="The file could not be read as a CSV.")

    expected = prediction.FEATURES + ["expenditure"]
    missing = [column for column in expected if column not in new_data.columns]
    if missing:
        raise HTTPException(status_code=400, detail=f"Missing columns: {missing}")
    if new_data.empty:
        raise HTTPException(status_code=400, detail="The file has no rows.")

    for number, row in new_data[expected].iterrows():
        values = row[prediction.FEATURES].to_dict()
        if pd.isna(values["payer"]):
            values["payer"] = "Father"   
        try:
            prediction.Student(**values)
        except ValidationError as error:
            raise HTTPException(status_code=422, detail=f"Row {number + 2}: {error.errors()[0]['msg']} ({error.errors()[0]['loc'][0]})")
        if not row["expenditure"] > 0:
            raise HTTPException(status_code=422, detail=f"Row {number + 2}: expenditure must be above 0")

    new_data = new_data[expected].copy()
    new_data["expenditure"] = new_data["expenditure"].astype(float)
    last_step = prediction.model.steps[-1][1]

    if isinstance(last_step, SGDRegressor):
        # keep training the saved model on the new rows only
        last_step.partial_fit(prediction.model[:-1].transform(new_data[prediction.FEATURES]), np.log1p(new_data["expenditure"]))
        method = "partial_fit on the new rows"
    else:
        # refit on the original data plus the new rows, then /predict switches to the new model
        original = pd.read_csv(TRAIN_PATH)
        everything = pd.concat([original, new_data], ignore_index=True)
        new_model = clone(prediction.model)
        new_model.fit(everything[prediction.FEATURES], np.log1p(everything["expenditure"]))
        prediction.model = new_model
        method = f"refit on {len(original)} original rows plus {len(new_data)} new rows"

    return {"message": "Model retrained and now used by /predict", "model": type(last_step).__name__, "method": method}
