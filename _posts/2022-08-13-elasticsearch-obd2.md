---
layout: post
comments: true
title: Exploring car diagnostic data with Elasticsearch and Kibana
excerpt: Learn how to use obd2 reader to capture your car diagnostic data and then upload it to Elasticsearch via Kibana UI.
categories: elasticsearch
tags: [elasticsearch,python,obd2]
toc: true
img_excerpt:
---

<img align="left" src="/assets/logos/elasticsearch.svg" width="120" />
<img align="center" src="/assets/logos/kibana.svg" width="100" />
<br/>

In this article we will collect car diagnostic data using python and ELM327 WIFI OBD2 Scanner, once data is collected we will import it into Elasticsearch for analysis.

## Collecting data with an OBD2 Scanner

To be able to collect the data you may need to get a Professional ELM327 WIFI OBD2 Scanner Code Reader/Erases Auto Diagnostic Tool like the one depicted in the following picture.

![ELM327 WIFI OBD2 Scanner]({{ "/assets/2022/08/2022-08-13-ELM327-WIFI-OBD2-Scanner.jpg" | absolute_url }})

Once the scanner is plugged into the car, it will create a WiFi network that you will need to connect to it. Note: you will need to disconnect from any other wifi network.


Next step is to clone the [python-OBD-wifi](https://github.com/dailab/python-OBD-wifi) repository which contains the python module for the OBD2 protocol.
```shell
$ git clone https://github.com/dailab/python-OBD-wifi
```

This python library is very easy to use to connect to the scanner and interacts with it:
1. Create an `obd.OBD` instance with the IP address of the scanner
1. Submit a command and interepret the response

```python
import obd

connection = obd.OBD("192.168.0.10", 35000)
response = connection.query("SPEED")
print(response.value)
```

In our case, we will try to query with all supported commands by the scanner, collect each of the responses into one dictionnary and dump it as one line to an output file. This is what the following script pretty much does:

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

Here is an example of a single json row that the script outputs for my car. You should get different values based whether the car is running or not, how long the engine was started, etc.

```json
{
  "time": "07/28/2022 18:08:00",
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

The size of the output file can grow very rapidely depending on the frequency of collection. You can leave the script running for few minutes it should give you enough data to index and verify the rest of the pipeline before trying to collect/ingest larger file.

## Importing the data into ElasticSearch
We need ElasticSearch / Kibana up and running so that we can import the data that we collected in the previous section.

### Setting up ElasticSearch / Kibana
From ElasticSearch root directory, start elasticsearch server
```shell
$ ./bin/elasticsearch
...
[2022-08-13T18:24:30,482][INFO ][o.e.n.Node               ] [unknown] started
[2022-08-13T18:24:30,985][INFO ][o.e.l.LicenseService     ] [unknown] license [300894ae-b6a0-4964-886f-d3fa540b9480] mode [basic] - valid
```
You can validate it started by visiting [http://localhost:9200/]() which may return a JSON payload like
```json
{
  "name" : "unknown",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "LtxiG0t8SdaLVSgzJznW_Q",
  "version" : {
    "number" : "7.14.0",
    "build_flavor" : "default",
    "build_type" : "tar",
    "build_hash" : "dd5a0a2acaa2045ff9624f3729fc8a6f40835aa1",
    "build_date" : "2021-07-29T20:49:32.864135063Z",
    "build_snapshot" : false,
    "lucene_version" : "8.9.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```

From Kibana root directory, start kibana UI server
```shell
$ ./bin/kibana
...
  log   [18:27:16.988] [info][monitoring][monitoring][plugins] config sourced from: production cluster
  log   [18:27:18.889] [info][server][Kibana][http] http server running at http://localhost:5601
  log   [18:27:19.077] [info][kibana-monitoring][monitoring][monitoring][plugins] Starting monitoring stats collection
  log   [18:27:19.169] [info][plugins][securitySolution] Dependent plugin setup complete - Starting ManifestTask
  log   [18:27:19.619] [info][plugins][reporting] Browser executable: /Users/bachirchihani/Tools/kibana-7.14.0-darwin-x86_64/x-pack/plugins/reporting/chromium/headless_shell-darwin_x64/headless_shell
  log   [18:27:22.674] [info][status] Kibana is now available (was unavailable)
```

Kibana UI should be available at [http://localhost:5601/]()

### Ingesting data with Kibana UI
Once ElasticSearch and Kibana services are started we can ingest the diagnostic data. Kibana make it very easy to ingest small size files, the following video illustrates how to upload our diagnostic data file.

![OBD2 data import with Kibana wizard]({{ "/assets/2022/08/2022-08-13-kibana-import.gif" | absolute_url }})

## That's all folks
I hope this article was helpfull to get you started with collecting diagnostic data for your car and playing with it in ElasticSearch.

I would love to hear any feedack, suggestions or ideas for improvement. So feel free to leave a comment or reach out on twitter [@bachiirc](https://twitter.com/bachiirc)