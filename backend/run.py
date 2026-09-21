import uvicorn
import socket
import sys

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

if __name__ == "__main__":
    port = 8000
    local_ip = get_local_ip()

    print("=" * 60)
    print("   LNote Synchronization Backend Server")
    print("=" * 60)
    print(f" * Localhost (Laptop):  http://127.0.0.1:{port}")
    print(f" * Wi-Fi/LAN (Mobile):  http://{local_ip}:{port}")
    print(f" * API Documentation:   http://127.0.0.1:{port}/docs")
    print(f" * Health Endpoint:     http://{local_ip}:{port}/api/health")
    print("=" * 60)
    print("Enter the Wi-Fi/LAN URL above into your Mobile app's Profile page.")
    print("=" * 60 + "\n")

    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
