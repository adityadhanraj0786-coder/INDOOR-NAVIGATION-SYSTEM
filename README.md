# INDOOR-NAVIGATION-SYSTEM

NavU is an indoor navigation project for college buildings. This version preserves the original core idea of map viewing plus live indoor routing, while improving the app structure, backend contract, and local-network configuration.

## What was improved

- Updated the Flutter frontend to use the new backend host `192.168.1.7:8000`.
- Cleaned up the home, map, navigation, and profile screens.
- Fixed the route API integration so frontend and backend agree on the `/route` contract.
- Added a stable Python entrypoint in `server.py`.
- Reduced unnecessary Android permissions and enabled local HTTP access.
- Added iOS location and local-network friendly settings for the same routing flow.

## Run the backend

Install the Python dependencies first, then start the FastAPI server:

```bash
pip install -r requirements.txt
python server.py
```

The API will listen on:

```text
http://0.0.0.0:8000
```

Useful endpoints:

- `GET /health`
- `GET /route`
- `POST /route`

## Run the Flutter app

From the `frontend` folder:

```bash
flutter pub get
flutter run
```

If you ever change the backend machine again, you can override the host without editing code:

```bash
flutter run --dart-define=NAVU_API_HOST=192.168.1.7:8000
```

## Important note about the report

The report file path you shared, `C:\CSA\PRACTICAL5\IMPROVEMENT_REPORT.md`, is currently empty on disk. The changes above are based on concrete issues already present in the project plus your new IP update. If you send the actual report content, the remaining report-specific items can be applied in a second pass.
