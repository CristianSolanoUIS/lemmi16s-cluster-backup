import psutil
import time

# Store previous readings for calculating deltas
last_disk = psutil.disk_io_counters()
last_net = psutil.net_io_counters()
last_time = time.time()

def get_system_stats():
    global last_disk, last_net, last_time

    now = time.time()
    elapsed = now - last_time
    last_time = now

    current_disk = psutil.disk_io_counters()
    current_net = psutil.net_io_counters()

    read_mb_s = (current_disk.read_bytes - last_disk.read_bytes) / 1_048_576 / elapsed
    write_mb_s = (current_disk.write_bytes - last_disk.write_bytes) / 1_048_576 / elapsed

    upload_kbps = (current_net.bytes_sent - last_net.bytes_sent) * 8 / 1024 / elapsed
    download_kbps = (current_net.bytes_recv - last_net.bytes_recv) * 8 / 1024 / elapsed

    last_disk = current_disk
    last_net = current_net

    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')

    stats = {
        "cpu": psutil.cpu_percent(),
        "memory_percent": memory.percent,
        "memory_used_mb": memory.used // 1024 // 1024,
        "memory_total_mb": memory.total // 1024 // 1024,
        "temp": get_cpu_temp(),
        "disk_read_mb_s": round(read_mb_s, 2),
        "disk_write_mb_s": round(write_mb_s, 2),
        "net_up_kbps": round(upload_kbps, 2),
        "net_down_kbps": round(download_kbps, 2),
        "disk_usage_percent": disk.percent
    }
    return stats

def get_cpu_temp():
    try:
        with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
            temp = int(f.read()) / 1000.0
        return round(temp, 1)
    except:
        return None
