---
layout: post
comments: true
title: Capture car diagnostic data and index them with Elasticsearch
excerpt: Learn how to use obd2 reader to capture your car diagnostic data and then upload it to Elasticsearch.
categories: certification
tags: [elasticsearch,python,obd]
toc: true
img_excerpt:
---


Professional ELM327 WIFI OBD2 Scanner Code Reader/Erases Auto Diagnostic Tool

```shell
$ git clone https://github.com/dailab/python-OBD-wifi
```


```python
import obd
import time
import json


status_commands = {"DTC_FUEL_STATUS", "STATUS", "STATUS_DRIVE_CYCLE", "DTC_STATUS", "DTC_STATUS_DRIVE_CYCLE"}#, "FUEL_STATUS"
tuple_commands = {"FREEZE_DTC"}

def main():
  connection = obd.OBD("192.168.0.10", 35000)
  f = open('obd-data.json', 'a')
  while True:
    line = json.dumps(read(connection))
    f.write(line + "\n")
    f.flush()
    time.sleep(10)


def read(connection):
  line = {"time": time.strftime("%m/%d/%Y %H:%M:00", time.localtime())}
  for cmd in connection.supported_commands:
    name = cmd.name
    response = connection.query(cmd)
    value = response.value
    if name in status_commands and value is not None:
      line[name+".MIL"] = value.MIL
      line[name+".DTC_count"] = value.DTC_count
      line[name+".ignition_type"] = value.ignition_type
    elif name in tuple_commands and value is not None:
      line[name+".code"] = value[0]
      line[name+".description"] = value[1]
    elif hasattr(value, 'magnitude'):
      line[name] = value.magnitude
    else:
      line[name] = str(value)
  return line


if __name__ == "__main__":
  main()
```

```json
{
  "time": "08/28/2021 18:08:00",
  "WARMUPS_SINCE_DTC_CLEAR": 2,
  "RELATIVE_THROTTLE_POS": 0,
  "DTC_RUN_TIME": "None",
  "ELM_VERSION": "ELM327 v1.5",
  "ABSOLUTE_LOAD": 21.96078431372549,
  "DTC_STATUS_DRIVE_CYCLE": "None",
  "DTC_DISTANCE_SINCE_DTC_CLEAR": "None",
  "RUN_TIME": 56,
  "PIDS_A": "10111110000111111010100000010011",
  "DTC_O2_B1S2": "None",
  "ACCELERATOR_POS_E": 31.764705882352942,
  "DTC_CONTROL_MODULE_VOLTAGE": "None",
  "EVAP_VAPOR_PRESSURE_ABS": 99.94,
  "PIDS_B": "10010000000001011011000000010101",
  "DTC_STATUS": "None",
  "O2_B1S2": 0,
  "FUEL_STATUS": "('Closed loop, using oxygen sensor feedback to determine fuel mix', '')",
  "OBD_COMPLIANCE": "OBD-II as defined by the CARB",
  "RPM": 916.25,
  "THROTTLE_ACTUATOR": 16.862745098039216,
  "CLEAR_DTC": "None",
  "DTC_SHORT_O2_TRIM_B1": "None",
  "MONITOR_PURGE_FLOW": "Unknown : 0.0 kilopascal [PASSED]\nUnknown : 0.0 kilopascal [PASSED]\nUnknown : 0.0 kilopascal [PASSED]\nUnknown : 0.0 kilopascal [PASSED]\nUnknown : 0.0 kilopascal [PASSED]\nUnknown : 0.0 kilopascal [PASSED]\nUnknown : 0.0 kilopascal [PASSED]\nUnknown : 0.0 kilopascal [PASSED]",
  "DTC_RELATIVE_THROTTLE_POS": "None",
  "DTC_COMMANDED_EQUIV_RATIO": "None",
  "BAROMETRIC_PRESSURE": 99,
  "DTC_EVAPORATIVE_PURGE": "None",
  "DTC_PIDS_B": "None",
  "COMMANDED_EQUIV_RATIO": 0.998997,
  "DTC_ACCELERATOR_POS_E": "None",
  "CONTROL_MODULE_VOLTAGE": 13.959,
  "DTC_CATALYST_TEMP_B1S1": "None",
  "MIDS_C": "01000000000000000000000000000001",
  "MONITOR_FUEL_SYSTEM_B1": "Unknown : 0.0 count [PASSED]\nUnknown : 0.0 count [PASSED]\nUnknown : 0.0 count [PASSED]\nUnknown : 0.0 count [PASSED]\nUnknown : 0.0 count [PASSED]",
  "DTC_FUEL_TYPE": "None",
  "STATUS_DRIVE_CYCLE.MIL": false,
  "STATUS_DRIVE_CYCLE.DTC_count": 0,
  "STATUS_DRIVE_CYCLE.ignition_type": "spark",
  "DISTANCE_W_MIL": 0,
  "DTC_WARMUPS_SINCE_DTC_CLEAR": "None",
  "INTAKE_TEMP": 31,
  "CATALYST_TEMP_B1S2": 68.7,
  "EVAPORATIVE_PURGE": 0,
  "MONITOR_MISFIRE_CYLINDER_1": "Average misfire counts for last ten driving cycles : 0.0 count [PASSED]\nMisfire counts for last/current driving cycles : 0.0 count [PASSED]",
  "O2_S1_WR_CURRENT": -0.00390625,
  "TIMING_ADVANCE": 5,
  "DTC_INTAKE_TEMP": "None",
  "DTC_THROTTLE_POS": "None",
  "RUN_TIME_MIL": 0,
  "DTC_BAROMETRIC_PRESSURE": "None",
  "DTC_RUN_TIME_MIL": "None",
  "PIDS_C": "11111010110111001010110000000001",
  "DTC_TIME_SINCE_DTC_CLEARED": "None",
  "SHORT_FUEL_TRIM_1": 0,
  "DTC_MAF": "None",
  "MIDS_E": "10000000000000000000000000000001",
  "DTC_THROTTLE_POS_B": "None",
  "O2_S1_WR_VOLTAGE": 3.3146257724879837,
  "DTC_ABSOLUTE_LOAD": "None",
  "MIDS_B": "10000000000000000000100000001001",
  "GET_CURRENT_DTC": "[]",
  "STATUS.MIL": false,
  "STATUS.DTC_count": 0,
  "STATUS.ignition_type": "spark",
  "DTC_COOLANT_TEMP": "None",
  "LONG_O2_TRIM_B1": 0,
  "ENGINE_LOAD": 34.509803921568626,
  "MONITOR_MISFIRE_CYLINDER_4": "Average misfire counts for last ten driving cycles : 0.0 count [PASSED]\nMisfire counts for last/current driving cycles : 0.0 count [PASSED]",
  "DTC_CATALYST_TEMP_B1S2": "None",
  "THROTTLE_POS_B": 49.01960784313726,
  "DTC_LONG_FUEL_TRIM_1": "None",
  "MONITOR_O2_B1S2": "Maximum sensor voltage for test cycle : 0.0 volt [PASSED]\nUnknown : 0.0 millisecond [PASSED]\nUnknown : 0.0 count [PASSED]\nUnknown : 0.0 count [PASSED]",
  "MIDS_A": "11000000000000000000000000000001",
  "MONITOR_O2_B1S1": "Unknown : 0.0 milliampere [PASSED]\nUnknown : 0.0 millivolt [PASSED]\nUnknown : 0.0 millivolt [PASSED]\nUnknown : 0.0 millisecond [PASSED]\nUnknown : 0.0 millisecond [PASSED]",
  "DISTANCE_SINCE_DTC_CLEAR": 0,
  "MIDS_F": "11111000000000000000000000000000",
  "O2_SENSORS": "((), (False, False, False, False), (False, False, True, True))",
  "FUEL_TYPE": "Gasoline",
  "MAF": 3.37,
  "DTC_O2_SENSORS": "None",
  "ELM_VOLTAGE": 12.7,
  "SPEED": 0,
  "MIDS_D": "00000000000000000000000000000001",
  "DTC_FUEL_STATUS": "None",
  "MONITOR_MISFIRE_GENERAL": "Average misfire counts for last ten driving cycles : 0.0 count [PASSED]\nMisfire counts for last/current driving cycles : 0.0 count [PASSED]",
  "DTC_RPM": "None",
  "CATALYST_TEMP_B1S1": 288.8,
  "MONITOR_O2_HEATER_B1S2": "Unknown : 0.0 milliohm [PASSED]",
  "MONITOR_MISFIRE_CYLINDER_3": "Average misfire counts for last ten driving cycles : 0.0 count [PASSED]\nMisfire counts for last/current driving cycles : 0.0 count [PASSED]",
  "DTC_SPEED": "None",
  "DTC_SHORT_FUEL_TRIM_1": "None",
  "DTC_EVAP_VAPOR_PRESSURE_ABS": "None",
  "MONITOR_CATALYST_B1": "Unknown : 0.0 count [PASSED]",
  "DTC_TIMING_ADVANCE": "None",
  "DTC_DISTANCE_W_MIL": "None",
  "DTC_O2_S1_WR_CURRENT": "None",
  "DTC_LONG_O2_TRIM_B1": "None",
  "DTC_O2_S1_WR_VOLTAGE": "None",
  "DTC_PIDS_C": "None",
  "COOLANT_TEMP": 65,
  "DTC_ACCELERATOR_POS_D": "None",
  "MONITOR_VVT_B1": "Unknown : 0.0 millisecond [PASSED]\nUnknown : 0.0 millisecond [PASSED]",
  "LONG_FUEL_TRIM_1": -7.03125,
  "DTC_ENGINE_LOAD": "None",
  "ACCELERATOR_POS_D": 16.07843137254902,
  "MONITOR_MISFIRE_CYLINDER_2": "Average misfire counts for last ten driving cycles : 0.0 count [PASSED]\nMisfire counts for last/current driving cycles : 0.0 count [PASSED]",
  "SHORT_O2_TRIM_B1": 0,
  "TIME_SINCE_DTC_CLEARED": 0,
  "DTC_THROTTLE_ACTUATOR": "None",
  "DTC_OBD_COMPLIANCE": "None",
  "THROTTLE_POS": 16.862745098039216,
  "GET_DTC": "[]"
}
```