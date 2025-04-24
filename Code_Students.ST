
Se på IO_Pagedata.hpg FOR information on what is the calls FOR each port in the I / O module


CASE state OF
	0 : // INIT
	IO.xQA1_RIGHT := TRUE;  // Kør båndet mod højre
	IO.xMB20 := FALSE; // gate up
	RFID.ClearError(); // Fjern alle errormessages fra RFID
	TCPclient.Connect(sIP := '172.20.66.30', uiPort := 65432); // Forbind til IP addresse XXX igennem port XXX
	state := 1; // Skift state


	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Startup FOR RFID sensor - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	1 : // wait for RFID
	IF RFID.xReady THEN    // Vent indtil RFID er klar til at  modtage data
		RFID.Connect(usiNodeId := 32, usiNetworkId := 0, usiChannel := 1);     // Forbind RFID sensor
		state := 2; // Skift state
	END_IF


	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	2 : // wait for connect TCP + RFID
	IF RFID.xReady AND TCPclient.xConnected AND TCPclient.xReady THEN    // Vent indtil RFID, TCP er klar og forbundet
		state := 3; // Skift state
	END_IF

	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	3 : // wait to slow incoming carrier
	IF IO.xBG24 = TRUE THEN     // Se efter om der er modtaget noget på sensor BG24 i I/O modulet (Den første modtager af scanner på båndet)
		IO.xQA1_SLOW := TRUE;    // Hvis der er modtaget noget skal hastigheden sættes ned
		state := 4; // Skift state
	END_IF

	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	4 : // read RFID tag once carrier arrives
	IF IO.xBG21 = TRUE THEN     // Se efter om sensorBG21 er aktiv, (Den sodste sensor på båndet)
		IO.xQA1_RIGHT := FALSE;    // Stop båndet
		RFID.ReadTag(uiStartAddress := 0, uiDataLength := SIZEOF(RFIDdata), ADR(RFIDdata));    // Resad sensor data for RFID
		DateTimeFB.xExecute := TRUE;    // Noter dato og tid for tidspunktet
		timer(IN := TRUE, PT := T#2s); // wait for RFID to read og sæt en timer på 2 sek.
		// TCPclient.Send(pToSend:=ADR(dataOut),uiSizeToSend:=SIZEOF(dataOut));
		state := 5; // Skift state
	END_IF


	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	5 : // send RFID message through TCP
	IF RFID.xReady AND timer.Q = TRUE AND DateTimeFB.xDone THEN     // Hvis RFID er aktiv, Timer tid er gået, og datastempelt er lavet
		corrected_ID := dc_ecp.SwapWord(RFIDdata.uiCarrierID);    // Opdater ID /Correct id
		datehold := DateTimeFB.dtDateAndTime;    // Sate time and date for tidpunktet
		datetimeString := DT_TO_STRING(datehold);    // ændre data+tid til string
		dataOut := CONCAT('<Info><carrier_id>', CONCAT(DWORD_TO_STRING(corrected_ID), CONCAT('</carrier_id><station_number>11</station_number><DATE>', CONCAT(datetimeString, '</DATE></Info>'))));     // Lav string for gemme data som JSON object
		// dataOut := CONCAT(CONCAT(DWORD_TO_STRING(corrected_ID),',11,'), CONCAT(datetimeString,','));
		TCPclient.Send(pToSend := ADR(dataOut), uiSizeToSend := SIZEOF(dataOut));     // Send dataOut via TCP client
		state := 6; // Skift state
	END_IF

	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	6 : // wait until done sending through TCP
	IF TCPclient.xReady THEN    // vent indtil TCP er klar til at modtage
		TCPclient.Receive(pToReceive := ADR(dataIn), uiSizeToReceive := SIZEOF(dataIn));     // Modtag bedskeden der er sent over TCP
		state := 7; // Skift state
	END_IF

	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	7 : // wait until receive message
	IF TCPclient.xReady THEN    // vent indtil TCP er klar
		// Process recieved data here //
		IF dataIn < 1500 THEN     // Hvis dataIn Variabel er midnre end 1500, tid modtaget via TCP client
			timer2(IN := TRUE, PT := DWORD_TO_TIME(dataIn)); // start timer for keep carrier i XX tid
			state := 8;  // Skift state
		ELSE
			state := 9; // pass carrier  // Skift state
		END_IF
	END_IF

	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	8 : // wait until time has passed
	IF timer2.Q = TRUE THEN    // vent indtil tiden er gået for Vent fra TCP clientEND_TCP
		timer2(IN := FALSE);    // når tiden er gået, så skal timer stoppes
		state := 9; // Skift state
	END_IF

	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	9 : // wait to send carrier away
	IF IO.xBG21 = TRUE THEN    // Så længe sensor BG21 er aktiv, carrier er ved stationen
		IO.xQA1_RIGHT := TRUE;    // Få båndet til at køre mod højre
		IO.xMB20 := TRUE; // gate down
		IO.xQA1_SLOW := FALSE;    //
		state := 10; // Skift state
	END_IF

	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	10 : // wait for carrier pass
	IF IO.xBG21 = FALSE THEN    // Er carrier væk fra sensor BG21
		IO.xMB20 := FALSE; // gate up
		state := 3; // Skift state
	END_IF

	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

END_CASE // End of looop, slut med switch case og den er klar til at starte forfra, efter de sidste funcs er kaldt
timer(); // timer til ?
timer2(); // timer for holde bestemt carrier
RFID(); // For updating RFID scanner
TCPclient(); // For updating TCPscanning og connection
DateTimeFB(); // For Getting time and date for logging
