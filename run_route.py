from three_dimension import IndoorRouter
import json
import matplotlib.pyplot as plt

# Initialize the router (only once)
router = IndoorRouter(
    source_crs="EPSG:4326"
)

# Ask the user for input
user_lat = float(input("Enter your latitude (e.g. 28.61301): "))
user_lon = float(input("Enter your longitude (e.g. 77.20905): "))
user_floor_input = input("Enter your floor (press Enter for floor 3): ").strip()
user_floor = int(user_floor_input) if user_floor_input else 3
target_name = input("Enter the target room name (e.g. Room 302): ")
target_floor = input("Enter target floor (press Enter for floor 3): ")

# Convert target_floor to int if provided
target_floor = int(target_floor) if target_floor.strip() else 3

# Get the route
try:
    result = router.route(
        user_lon=user_lon,
        user_lat=user_lat,
        target_name=target_name,
        user_floor=user_floor,
        target_floor=target_floor,
    )

    # Print route details
    print("\n📍 ROUTE RESULT 📍")
    print(json.dumps(result, indent=2, ensure_ascii=False))

    print("\n🧭 Step-by-step instructions:")
    for step in result["instructions"]:
        print("  -", step)

    # --------------------------
    # Plot the route graphically
    # --------------------------

    # Extract path coordinates
    path_lons = [node["lon"] for node in result["path"]]
    path_lats = [node["lat"] for node in result["path"]]

    # Extract all nodes for background
    all_lons = [node["lon"] for node in router.nodes.values()]
    all_lats = [node["lat"] for node in router.nodes.values()]

    # Create plot
    plt.figure(figsize=(8, 6))
    plt.scatter(all_lons, all_lats, c='lightgray', label='All nodes', zorder=1)
    plt.plot(path_lons, path_lats, c='red', linewidth=2, marker='o', label='Route', zorder=2)
    plt.xlabel("Longitude")
    plt.ylabel("Latitude")
    plt.title(f"Route to {target_name} (Floor {target_floor})")
    plt.legend()
    plt.grid(True)
    plt.show()

except Exception as e:
    print("❌ Error:", e)

