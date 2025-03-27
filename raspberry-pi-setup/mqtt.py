import serial
import paho.mqtt.client as mqtt

# Configuration
SERIAL_PORT = "/dev/ttyACM0"  # Replace with your Arduino's serial port
BAUD_RATE = 9600
MQTT_BROKER = "127.0.0.1"  # Replace with your MQTT broker address
MQTT_PORT = 1883
MQTT_TOPIC = "sensor/temperature"

# Connect to the serial port
ser = serial.Serial(SERIAL_PORT, BAUD_RATE)

# Connect to the MQTT broker
client = mqtt.Client()
client.connect(MQTT_BROKER, MQTT_PORT, 60)

try:
    while True:
        # Read a line from the serial port
        line = ser.readline().decode("utf-8").strip()

        # Skip blank lines
        if not line:
            continue

        # Publish the line to the MQTT topic
        client.publish(MQTT_TOPIC, line)
        print(f"Published: {line}")
except KeyboardInterrupt:
    print("Exiting...")
finally:
    ser.close()
    client.disconnect()