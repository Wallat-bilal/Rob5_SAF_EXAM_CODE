

CASE state OF
	0: // INIT
	IO.xQA1_RIGHT := TRUE;
	IO.xMB20 := FALSE; //gate up
	RFID.ClearError();
	TCPclient.Connect(sIP :='172.20.66.30', uiPort :=65432);
	state := 1;
	
	1: //wait for RFID
	IF RFID.xReady THEN
		RFID.Connect(usiNodeId := 32, usiNetworkId := 0, usiChannel := 1);
		state := 2;
	END_IF
	
	2: //wait for connect TCP + RFID
	IF RFID.xReady AND TCPclient.xConnected AND TCPclient.xReady THEN
		state := 3;
	END_IF
	
	3: //wait to slow incoming carrier
	IF IO.xBG24 = TRUE THEN
		IO.xQA1_SLOW := TRUE;
		state := 4;
	END_IF
	
	4: //read RFID tag once carrier arrives
	IF IO.xBG21 = TRUE THEN
		IO.xQA1_RIGHT := FALSE;
		RFID.ReadTag(uiStartAddress := 0, uiDataLength := SIZEOF(RFIDdata), ADR(RFIDdata));
		DateTimeFB.xExecute := TRUE;
		timer(IN:=TRUE, PT:=T#2S); //wait for RFID to read
		//TCPclient.Send(pToSend:=ADR(dataOut),uiSizeToSend:=SIZEOF(dataOut));
		state := 5;
	END_IF
	
	
	5: //send RFID message through TCP
	IF RFID.xReady AND timer.Q = TRUE AND DateTimeFB.xDone THEN
		corrected_ID := dc_ecp.SwapWord(RFIDdata.uiCarrierID); 
		datehold := DateTimeFB.dtDateAndTime;
		datetimeString :=DT_TO_STRING(datehold);
		dataOut :=CONCAT('<Info><carrier_id>',CONCAT(DWORD_TO_STRING(corrected_ID),CONCAT('</carrier_id><station_number>11</station_number><DATE>',CONCAT(datetimeString,'</DATE></Info>'))));
		//dataOut := CONCAT(CONCAT(DWORD_TO_STRING(corrected_ID),',11,'), CONCAT(datetimeString,','));
		TCPclient.Send(pToSend:=ADR(dataOut),uiSizeToSend:=SIZEOF(dataOut));
		state := 6;
	END_IF
	
	6: //wait until done sending through TCP
	IF TCPclient.xReady THEN
		TCPclient.Receive(pToReceive:=ADR(dataIn),uiSizeToReceive:=SIZEOF(dataIn));
		state := 7;
	END_IF
	
	7: //wait until receive message
	IF TCPclient.xReady THEN
		//Process recieved data here//
		IF dataIn < 1500 THEN
			timer2(IN:=TRUE, PT:=DWORD_TO_TIME(dataIn)); //keep carrier
			state := 8; 
		ELSE
			state := 9; //pass carrier
		END_IF
	END_IF
	
	8: //wait until time has passed
	IF timer2.Q = TRUE THEN
		timer2(IN:=FALSE);
		state := 9;
	END_IF
	
	9: //wait to send carrier away
	IF IO.xBG21 = TRUE THEN
		IO.xQA1_RIGHT := TRUE;
		IO.xMB20 := TRUE; //gate down
		IO.xQA1_SLOW := FALSE;
		state := 10;
	END_IF
	
	10: //wait for carrier pass
	IF IO.xBG21 = FALSE THEN
		IO.xMB20 := FALSE; //gate up
		state := 3;
	END_IF
	
END_CASE
timer();
timer2();
RFID();
TCPclient();
DateTimeFB();