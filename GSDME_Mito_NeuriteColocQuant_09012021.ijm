getSelectionCoordinates(xpoints, ypoints);
run("Select None");
imageID=getImageID();
channelForMeasuring=getNumber("Channel number for measuring", 1);
channelForMasking=getNumber("Channel number for making mask", 2);
objectSize=getNumber("Typical length of object", 3);


// getting gray values for measuring //
Stack.setChannel(channelForMeasuring);
makeSelection("polyline", xpoints, ypoints);
grayValues=getProfile();
grayValues=rollingAverage1D(grayValues,objectSize);
grayValues=normalizeToBaseline1D(grayValues);


// getting mitochondrial signal and converting to masks //
Stack.setChannel(channelForMasking);
makeSelection("polyline", xpoints, ypoints);
maskValues=getProfile();
maskValues=localContrast1D(maskValues,objectSize);
maskValues=rollingAverage1D(maskValues,objectSize);
maskValues=normalizeToBaseline1D(maskValues);
maskValues=makeMask1D(maskValues, 1);


// fixing selection for next time //
run("Interpolate", "interval=10 smooth");


// plotting //
Array.getStatistics(grayValues, min, max, mean, stdDev);
for (i = 0; i < maskValues.length; i++) {maskValues[i]=maskValues[i]*max;}
//Array.show("values", grayValues, maskValues);
Plot.create("Title", "X-axis Label", "Y-axis Label", maskValues); Plot.add("Filled", grayValues);
Plot.setStyle(1, "black,green,1.0,Filled"); Plot.setStyle(0, "red,red,1.0,Bar");

// calculating //
signalOutsideMask=0; signalInsideMask=0; 
pixelsOutsideMask=0; pixelsInsideMask=0;
for (i = 0; i < maskValues.length; i++) {
	if (maskValues[i]==0) {
		signalOutsideMask=signalOutsideMask+grayValues[i];
		pixelsOutsideMask=pixelsOutsideMask+1;
	}
	if (maskValues[i]>0) {
		signalInsideMask=signalInsideMask+grayValues[i];
		pixelsInsideMask=pixelsInsideMask+1;
	}
}
averageSignalOutsideMask=signalOutsideMask/pixelsOutsideMask;
averageSignalInsideMask=signalInsideMask/pixelsInsideMask;
ratio=averageSignalInsideMask/averageSignalOutsideMask;


// printing results //
Stack.getPosition(channel, slice, frame);
print(getInfo("image.filename"));
print("frame=	"+frame);
print("averageSignalOutsideMask=	"+averageSignalOutsideMask);
print("averageSignalInsideMask=	"+averageSignalInsideMask);
print("ratio=	"+ratio);













function makeMask1D(array, threshold) { 
	// function description
	arrayTmp=Array.copy(array);
	for (i = 0; i < array.length; i++) {
		if (array[i]>threshold){arrayTmp[i]=1;}
		if (array[i]<=threshold){arrayTmp[i]=0;}
	}
	return arrayTmp;
}





function normalizeToBaseline1D(array) {
	// substracting baselines //
	Array.getStatistics(array, minArray, max, meanArray, stdDev);
	for (i = 0; i < array.length; i++) {
		array[i]=array[i]/meanArray;
		if (array[i]<0){array[i]=0;}
	}
	return array;
}







function rollingAverage1D(array,rollingRadius) {
	 // smoothing profile //
	for (i = rollingRadius; i < array.length-rollingRadius; i++) {
		windowAverage=0; 
		for (j = 1; j < rollingRadius; j++) {
			windowAverage=windowAverage+array[i-j];
		}
		for (j = 1; j < rollingRadius; j++) {
			windowAverage=windowAverage+array[i+j];
		}
		windowAverage=windowAverage/(rollingRadius*2);
		array[i]=windowAverage;
	}
	return array;
}







function localContrast1D(array,rollingRadius) {
	array2=newArray(array.length);
	 
	// local contrast //
	for (i = rollingRadius; i < array.length-rollingRadius; i++) {
		windowAverage=0; 
		for (j = 1; j < rollingRadius; j++) {
			windowAverage=windowAverage+array[i-j];
		}
		for (j = 1; j < rollingRadius; j++) {
			windowAverage=windowAverage+array[i+j];
		}
		windowAverage=windowAverage/(rollingRadius*2);
		array2[i]=array[i]-windowAverage;
		if (array2[i]<0) {array2[i]=0;}
	}
	// local contrast (leading edge) //
		for (i = 0; i < rollingRadius; i++) {
			windowAverage=0; 
			for (j = 0; j < rollingRadius; j++) {
				windowAverage=windowAverage+array[i+j];
			}
			windowAverage=windowAverage/(rollingRadius);
			array2[i]=array[i]-windowAverage;
			if (array2[i]<0) {array2[i]=0;}
	}

	// local contrast (trailing edge) //
		for (i = array.length-rollingRadius; i < array.length; i++) {
			windowAverage=0; 
			for (j = 0; j < rollingRadius; j++) {
				windowAverage=windowAverage+array[i-j];
			}
			windowAverage=windowAverage/(rollingRadius);
			array2[i]=array[i]-windowAverage;
			if (array2[i]<0) {array2[i]=0;}
	}
	return array2;
}






function refineLineSelection(searchRadius, threshold){
	setLineWidth(searchRadius);
	run("To Selection");
	run("Fit Spline");
	run("Interpolate", "interval=1 smooth");
	getSelectionCoordinates(xpoints, ypoints);
	getSelectionCoordinates(xpointsCorrected, ypointsCorrected);
	for (i = searchRadius; i < xpoints.length-searchRadius; i++) {
		makeLine(xpoints[i-searchRadius], ypoints[i-searchRadius], xpoints[i+searchRadius], ypoints[i+searchRadius]);
		run("Rotate...", "  angle=90");
		run("Interpolate", "interval=1 smooth");
		getSelectionCoordinates(xpointsProfile, ypointsProfile);
		profile=getProfile();
		maxima=Array.findMaxima(profile, 1);
		maxima=maxima[0];
		if (profile[maxima]>threshold){xpointsCorrected[i]=xpointsProfile[maxima]; ypointsCorrected[i]=ypointsProfile[maxima];}
		if (profile[maxima]<=threshold) {xpointsCorrected[i]=xpoints[i]; ypointsCorrected[i]=ypoints[i];}
	}
	makeSelection("polyline", xpointsCorrected, ypointsCorrected);
	run("Properties... ", "  width=5");
	run("Interpolate", "interval=5 smooth");
}
