# README #

This is a Home Assistant interface for Garmin's Connect IQ devices.

* https://github.com/alanfischer/hassiq

It currently requires that you have a modified api.py that allows for restricting the requested results.  This is included in the custom_components directory.

Steps to install:

1. Copy custom_components/api.py into your .homeassistant/custom_components directory.
2. Create a group in home assistant called group.hassiq  This contains all the entities you wish to show on the HassIQ app.
3. Build HassIQ.prg and copy to the Apps directory on your Garmin.

