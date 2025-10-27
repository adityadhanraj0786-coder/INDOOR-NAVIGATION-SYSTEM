from three_dimension import IndoorRouter
import matplotlib.pyplot as plt
import json
import time

# ----------------------------
# Initialize Indoor Router
# ----------------------------
router = IndoorRouter(
    nodes_path="nodes.csv",
    edges_path="edges.csv",
    source_crs="EPSG:4326"
)

# Floor colors for visualization
FLOOR_COLORS = {0: "blue", 1: "green", 2: "orange", 3: "purple"}

# ----------------------------
# Function to plot route
# ----------------------------
def plot_route(result):
    plt.clf()  # clear previous plot
    # Plot all nodes by floor
    for nid, n in router.nodes.items():
        plt.scatter(n["lon"], n["lat"], 
                    c=FLOOR_COLORS.get(n["floor"], "gray"), 
                    s=50, label=f"Floor {n['floor']}" if n["floor"] not in plt.gca().get_legend_handles_labels()[1] else "")
    # Plot path
    path_lons = [node["lon"] for node in result["path"]]
    path_lats = [node["lat"] for node in result["path"]]
    plt.plot(path_lons, path_lats, c="red", linewidth=2, marker='o', label="Route")
    
    plt.xlabel("Longitude")
    plt.ylabel("Latitude")
    plt.title(f"Route to {target_name}")
    plt.legend()
    plt.grid(True)
    plt.pause(0.5)  # pause to update plot

# ----------------------------
# Real-time loop
# ----------------------------
plt.ion()  # turn on interactive mode
print("Enter user coordinates repeatedly to simulate movement. Type 'exit' to quit.\n")

target_name = input("Enter the target room name (e.g. Room 302): ")
target_floor = input("Enter target floor (or leave blank if unknown): ")
target_floor = int(target_floor) if target_floor.strip() else None

while True:
    user_lat_input = input("\nEnter your latitude (or 'exit'): ")
    if user_lat_input.lower() == "exit":
        break
    user_lon_input = input("Enter your longitude: ")
    user_floor_input = input("Enter your floor: ")
    
    try:
        user_lat = float(user_lat_input)
        user_lon = float(user_lon_input)
        user_floor = int(user_floor_input)
        
        # Get route
        result = router.route(
            user_lon=user_lon,
            user_lat=user_lat,
            target_name=target_name,
            user_floor=user_floor,
            target_floor=target_floor
        )
        
        # Print instructions
        print("\n🧭 Step-by-step instructions:")
        for step in result["instructions"]:
            print("  -", step)
        
        # Plot route
        plot_route(result)
        
    except Exception as e:
        print("❌ Error:", e)

plt.ioff()
plt.show()
