//
// Copyright 2015-2016 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

using Toybox.Ant;
using Toybox.WatchUi;
using Toybox.Time;
using Toybox.ActivityRecording;
using Toybox.FitContributor;

class BikePowerSensor extends Ant.GenericChannel {
    /*
	got : device number: 1005100 device type: 122 => Bike Cadence Sensor
    got : device number: 1019288 device type: 25 =>  Env Sensor (tempe ?)
	got : device number: 613759 device type: 120 => Heart Rate Sensor

	got	device number: 30 device type: 11 => Bike Power Sensors
	got	device number: 1005100 device type: 122

	BIKE_POWER(11, "Bike Power Sensors"),
	CONTROLLABLE_DEVICE(16, "Controls"),
	FITNESS_EQUIPMENT(17, "Fitness Equipment Devices"),
	BLOOD_PRESSURE(18, "Blood Pressure Monitors"),
	GEOCACHE(19, "Geocache Transmitters"),
	ENVIRONMENT(25, "Environment Sensors"),
	WEIGHT_SCALE(119, "Weight Sensors"),
	HEARTRATE(120, "Heart Rate Sensors"),
	BIKE_SPDCAD(121, "Bike Speed and Cadence Sensors"),
	BIKE_CADENCE(122, "Bike Cadence Sensors"),
	BIKE_SPD(123, "Bike Speed Sensors"),
	STRIDE_SDM(124, "Stride-Based Speed and Distance Sensors"),*/
    const DEVICE_TYPE = 11;
    const PERIOD = 8192;
    const Bike_FIELD_ID = 0;

    hidden var chanAssign;
    hidden var fitField;
    hidden var session;

    var data;
    var searching;
    var pastEventCount;
    
    var deviceCfg;

	var deviceid = null;
	
    class BikePowerData {        
        var eventCount;      
        var pedalPower;
        var cadence;
        var accumulatedPower;
        var instantPower;

        function initialize() {            
            eventCount = 0;
            pedalPower = 0;
            cadence = 0;
            accumulatedPower = 0;
            instantPower = 0;
        }
     
    }  

    class BikePowerDataPage {
        static const PAGE_NUMBER = 0x10;        

        function parse(payload, data) {
            System.println("BikePowerDataPage parse payload");
            data.eventCount = parseEventCount(payload);            
            data.pedalPower = parsePedalPower(payload);
            data.cadence = parseCadence(payload);
            data.accumulatedPower = parseAccumulatedPower(payload);
            data.instantPower = parseInstantPower(payload);
            //data.revolutionCount = parseRevolutionCount(payload);
            // TODO: rollover and better count
            //var cadence = (60 * 1024 * (revolutionCount - pastRevolutionCount))/(cadenceEvent-pastCadenceEvent);            
        }

        /*
         * always increment
         */
        hidden function parseOperatingTime(payload) {
            // always FF on DP 0
           return ((payload[1] | ((payload[2] ) << 8)) - ((payload[3] ) << 16 ));
        }

        hidden function parseEventCount(payload) {
           return (payload[1]);
        }

        hidden function parsePedalPower(payload) {
           return (payload[2]);
        }

        hidden function parseCadence(payload) {
           return (payload[3]);
        }

        hidden function parseAccumulatedPower(payload) {
           return ((payload[4] | ((payload[5] ) << 8)));
        }
        
        hidden function parseInstantPower(payload) {
           return ((payload[6] | ((payload[7] ) << 8)));
        }
     
    }


    function initialize() {
    	System.println("initialize"); 
        // Get the channel
        chanAssign = new Ant.ChannelAssignment(
            //Ant.CHANNEL_TYPE_RX_NOT_TX,
            Ant.CHANNEL_TYPE_RX_ONLY,
            Ant.NETWORK_PLUS);
        
        // background search ?
	    chanAssign.setBackgroundScan(true); 
	
        GenericChannel.initialize(method(:onMessage), chanAssign);
        fitField = null;

        // Set the configuration
        deviceCfg = new Ant.DeviceConfig( {
            :deviceNumber => 0,                 // Wildcard our search
            :deviceType => DEVICE_TYPE,
            :transmissionType => 0,
            :messagePeriod => PERIOD,
            :radioFrequency => 57,              // Ant+ Frequency
            :searchTimeoutLowPriority => 10,    // Timeout in 25s
            :searchThreshold => 0} );           // Pair to all transmitting sensors
        GenericChannel.setDeviceConfig(deviceCfg);

        data = new BikePowerData();
        searching = true;
        //session = ActivityRecording.createSession({:name=>WatchUi.loadResource(Rez.Strings.sessionName)});
    }

    function open() {
    	System.println("open");
        // Open the channel
        GenericChannel.open();

        data = new BikePowerData();
        pastEventCount = 0;
        searching = true;
        /*
        session.start();

        if(session has :createField) {
            if( null == fitField ) {
                fitField = session.createField
                    (
                    WatchUi.loadResource(Rez.Strings.fitFieldName),
                    Bike_FIELD_ID,
                    FitContributor.DATA_TYPE_FLOAT,
                    { :mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>WatchUi.loadResource(Rez.Strings.fitUnitsLabel)}
                    );
            }
        }
        */
    }

    function closeSensor() {
        GenericChannel.close();
        //session.stop();
        //session.save();
    }

    function dumpPage(payload) {
        System.println("payload :");
        System.println(payload); // better ?
    }

    function onMessage(msg) {
        if (msg.deviceNumber != null) {            
            System.println("device number: " + msg.deviceNumber + " device type: " + msg.deviceType);
            deviceid = msg.deviceType;
        }

	        // Parse the payload
        var payload = msg.getPayload();

        if (Ant.MSG_ID_BROADCAST_DATA == msg.messageId) {
            System.println("broadcast msg : data page : " + (payload[0].toNumber() )); 
            // page = page & 0x7f mask page change ?

            if (BikePowerDataPage.PAGE_NUMBER == (payload[0].toNumber() & 0xFF)) {
                // Were we searching?
                if (searching) {
                    searching = false;
                    // Update our device configuration primarily to see the device number of the sensor we paired to
                    deviceCfg = GenericChannel.getDeviceConfig();
                }
                var dp = new BikePowerDataPage();
                dp.parse(msg.getPayload(), data);
                // Check if the data has changed and we need to update the ui
                if (pastEventCount != data.eventCount) {
                    WatchUi.requestUpdate();
                    pastEventCount = data.eventCount;                    
/*
                    if(session.isRecording() && (fitField != null)) {
                        fitField.setData(data.totalHemoConcentration);
                    }
                   */
                }
            
            }
            /* end bypass */
        } else if (Ant.MSG_ID_CHANNEL_RESPONSE_EVENT == msg.messageId) {
            System.println("event msg");
            if (Ant.MSG_ID_RF_EVENT == (payload[0] & 0xFF)) {
                if (Ant.MSG_CODE_EVENT_CHANNEL_CLOSED == (payload[1] & 0xFF)) {
                    // Channel closed, re-open
                    System.println("channel close");
                    open();
                } else if (Ant.MSG_CODE_EVENT_RX_FAIL_GO_TO_SEARCH  == (payload[1] & 0xFF)) {
                    searching = true;
                    System.println("fail msg");
                    WatchUi.requestUpdate();
                }
            } else {
                //It is a channel response.
                System.println("response");
            }
        }
        

    }
}
