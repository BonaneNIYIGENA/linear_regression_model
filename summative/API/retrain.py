from io import BytesIO
from pathlib import Path

import numpy as np
import pandas as pd
from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import ValidationError
from sklearn.base import clone
from sklearn.linear_model import SGDRegressor

TRAIN_PATH = Path(__file__).parent / "data" / "train_data.csv"

router = APIRouter()

# the original rows plus everything uploaded so far
training = {"rows": None}


@router.post("/retrain")
async def retrain(file: UploadFile = File(..., description="CSV with the 9 input columns and expenditure (RWF)")):
    # imported here because prediction.py imports this file (avoids a circular import)
    import prediction

    name = (file.filename or "").lower()
    if name.endswith(".dta"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file. Convert the .dta first with the notebook (the cell that creates new_data_sample.csv).")
    if not name.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file.")

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

    new_data = new_data[expected].copy()
    new_data["expenditure"] = pd.to_numeric(new_data["expenditure"], errors="coerce")

    # every row follows the same rules as a /predict request
    for number, row in new_data.iterrows():
        values = row[prediction.FEATURES].to_dict()
        if pd.isna(values["payer"]):
            values["payer"] = "Father"   # a blank payer is allowed, the model fills it in itself
        try:
            prediction.Student(**values)
        except ValidationError as error:
            raise HTTPException(status_code=422, detail=f"Row {number + 2}: {error.errors()[0]['msg']} ({error.errors()[0]['loc'][0]})")
        if not row["expenditure"] > 0:
            raise HTTPException(status_code=422, detail=f"Row {number + 2}: expenditure must be a number above 0")

    last_step = prediction.model.steps[-1][1]

    if isinstance(last_step, SGDRegressor):
        # keep training the saved model on the new rows only
        last_step.partial_fit(prediction.model[:-1].transform(new_data[prediction.FEATURES]), np.log1p(new_data["expenditure"]))
        summary = {"method": "partial_fit on the new rows", "new_rows": len(new_data)}
    else:
        # refit on the original data plus the new rows
        if training["rows"] is None:
            training["rows"] = pd.read_csv(TRAIN_PATH)
        everything = pd.concat([training["rows"], new_data], ignore_index=True)

        new_model = clone(prediction.model)
        new_model.fit(everything[prediction.FEATURES], np.log1p(everything["expenditure"]))

        summary = {
            "method": "refit on the original data plus the new rows",
            "previous_rows": len(training["rows"]),
            "new_rows": len(new_data),
            "total_rows_used": len(everything),
        }
        prediction.model = new_model
        training["rows"] = everything

    return {"message": "Model retrained and now used by /predict", "model": type(last_step).__name__, **summary}
