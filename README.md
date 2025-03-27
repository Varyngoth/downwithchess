# Down with CHESS

## Introduction

This repository contains all of the files required to initialize a Raspberry Pi device as a local data logging platform. The breakdown shown within explains all steps required to install, initialize, manage, and deploy the aforementioned data logging platform. All files are included or pulled externally and are pre-configured for use as described within the following sections:

* Raspberry Pi preparation and OS setup
* Raspberry Pi program setup
* Program explanation and details
* Final considerations

## Raspberry Pi Preparation and OS Setup

## Raspberri Pi Program Setup

Copy and pase the following command into the command terminal for the Raspberry Pi

apt update && apt upgrade -y && apt install -y sudo curl git dos2unix python && git clone https://github.com/Varyngoth/downwithchess && cd downwithchess && python3 eduroam.py && dos2unix setup.sh && chmod +x setup.sh && bash setup.sh
