# Predicting Individual Schooling Expenditure in Rwanda

## Mission and problem

**Mission:** Reduce educational inequality through a transparent, secure and accessible platform where talented but financially disadvantaged students receive verified educational support from crowdfunding donors, organisations and scholarship providers.

**Problem:** Donors and scholarship providers can't tell how much a student realistically needs. This model predicts a student's yearly schooling expenditure (RWF) from basic profile details so that the support can be sized to a student's actual costs.

## Dataset

The Integrated Household Living Conditions Survey 2023-2024 (EICV7), collected by the National Institute of Statistics of Rwanda (NISR). I use the person-level file: 62,110 people and 157 columns from 15,054 households. The 23,091 people who went to school in the last 12 months are the rows I model. The target is their total yearly school spending in RWF, and the model uses nine inputs: age, sex, province, urban or rural area, school level, school type, boarding, household size and who pays.

Source: https://microdata.statistics.gov.rw/index.php/catalog/119/get_microdata

The file is in `summative/linear_regression/data/`, next to the notebook.

## Swagger UI (public API)

**https://linear-regression-model-h6i6.onrender.com/docs**

- `POST /predict`: the predicted yearly spending of one student
- `POST /retrain`: upload a CSV of new students (for example `summative/API/data/new_data_sample.csv`) to update the model

## Video demo

YouTube: https://youtu.be/FPihwQ0SxOM

## How to run the mobile app

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and Android Studio. Then create an Android emulator (**Device Manager → Create device**), or plug in an Android phone with USB debugging turned on.
2. Clone the repository:
   ```bash
   git clone https://github.com/BonaneNIYIGENA/linear_regression_model.git
   ```

   After cloning you get this structure:

   ```
   linear_regression_model/
   ├── README.md
   └── summative/
       ├── pyproject.toml, uv.lock       # uv project and packages
       ├── linear_regression/
       │   ├── multivariate.ipynb        # model training
       │   ├── data/                     # the dataset
       │   └── saved_models/             # all four trained models
       ├── API/
       │   ├── prediction.py             # FastAPI: /predict, CORS, input rules
       │   ├── retrain.py                # the /retrain route
       │   ├── pyproject.toml, uv.lock   # exact package versions
       │   ├── requirements.txt          # installed by Render
       │   ├── best_model.pkl            # the best model
       │   └── data/                     # training and retraining data
       └── FlutterApp/                   # the one-page Flutter app
   ```
3. Go to the app folder:
   ```bash
   cd linear_regression_model/summative/FlutterApp
   ```
4. Install the packages of the app:
   ```bash
   flutter pub get
   ```
5. Start the emulator (or plug in the phone) and check that Flutter sees it:
   ```bash
   flutter devices
   ```
6. Run the app:
   ```bash
   flutter run
   ```
7. Fill in the nine fields, for example: age `5`, sex `Male`, province `Kigali`, area `Urban`, school level `Nursery`, school type `Private`, boarding `Not applicable`, household size `6`, who pays `Father`. Tap **Predict**. The estimated yearly school spending appears under the button (about 340,217 RWF). A missing or wrong value shows an error message in the same place.


## Run everything on your computer

The project uses [uv](https://docs.astral.sh/uv/) for the Python packages.

```bash
cd linear_regression_model/summative
uv sync
```

- **Notebook:** open `linear_regression/multivariate.ipynb` and select the Python environment in `summative/.venv`.
- **API:** `cd API`, then `uv sync` (the API is its own small uv project), then `uv run uvicorn prediction:app --port 8000`, then open http://localhost:8000/docs
- **App with the local API on a phone:** run `adb reverse tcp:8000 tcp:8000`, then `flutter run --dart-define=API_URL=http://localhost:8000`

## Results

All four models were trained on the same split and tested on the same test set. The error is the MSE of the log of the spending, and always predicting the average gives 2.3017.

| Model | Train MSE | Test MSE |
|---|---|---|
| **RandomForestRegressor (best)** | 0.5192 | **0.6007** |
| DecisionTreeRegressor | 0.6005 | 0.6285 |
| LinearRegression | 0.6878 | 0.6624 |
| SGDRegressor | 0.6894 | 0.6636 |
