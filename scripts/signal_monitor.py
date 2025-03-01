import asyncio
import serial

async def monitor_signal(port="/dev/ttyUSB0"):
    ser = serial.Serial(port, 115200, timeout=1)
    while True:
        ser.write(b"AT+CSQ\r")
        response = await asyncio.to_thread(ser.readline)
        print(f"Signal: {response.decode().strip()}")
        await asyncio.sleep(0.5)

asyncio.run(monitor_signal())
