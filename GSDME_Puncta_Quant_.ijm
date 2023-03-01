while (selectionType()<0 ) {waitForUser("make Line Selection on channel to be quantified");}
getSelectionCoordinates(xpoints, ypoints);
run("Select None");
imageID=getImageID();
imageName=getTitle();


// getting signal and converting to masks //
run("Select None"); channel=1; slice=1; frame=1; 
if(nSlices>1){Stack.getPosition(channel, slice, frame);} // getting current position to report to user
run("Duplicate...", " "); imageID2=getImageID(); // duplicating current frame //
makeSelection("polyline", xpoints, ypoints); maskValues=getProfile(); // getting line profile
selectImage(imageID2); close();
selectImage(imageID); run("Restore Selection");
maskValues=stretchContrast(maskValues,1); // stretches contrast to 0 and 1 with over and unsaturation of 1%
//maskValues=normalizeToBaseline1D(maskValues);
maskValues=rollingAverage1D(maskValues,3);
maskValues=localContrast1D(maskValues,20);
Plot.create("Plot for setting threshold", "Length", "Intensities", Array.getSequence(maskValues.length), maskValues);
Plot.show();

// getting thresholding values //
maskThreshold=getNumber("Threshold For Masking", 2);
objectSizeMin=getNumber("Minimum length of object", 3);
objectSizeMax=getNumber("Max length of object", 20);

selectWindow("Plot for setting threshold"); run("Close");



maskValues=makeMask1D(maskValues, maskThreshold);


// put mask values into image to detect objects //
heightOfProfile=50;
for (i = 1; i < maskValues.length; i++) {maskValues[i]=maskValues[i]*255;}
newImage("profile", "8-bit black", maskValues.length, heightOfProfile, 1); profileID=getImageID();
setBatchMode("hide");
for (i = 1; i < maskValues.length; i++){
	for (h = 0; h < getHeight(); h++){
		selectImage(profileID); 
		makePoint(i, h, "small yellow hybrid");
		setPixel(i, h, maskValues[i]);
		
	}
}
setBatchMode("exit and display");

// getting rid of small objects //
selectImage(profileID); 
setOption("BlackBackground", true); run("Convert to Mask");
run("Analyze Particles...", "size="+0+"-"+heightOfProfile*objectSizeMin+" clear add");
setForegroundColor(0, 0, 0); roiManager("Fill");



// getting rid of large objects //
selectImage(profileID); 
setOption("BlackBackground", true); run("Convert to Mask");
run("Analyze Particles...", "size="+heightOfProfile*objectSizeMax+"-Infinity clear add");
setForegroundColor(0, 0, 0); roiManager("Fill");




// detect objects
selectImage(profileID); 
setOption("BlackBackground", true); run("Convert to Mask");
selectImage(profileID); 
run("Analyze Particles...", "size="+heightOfProfile*objectSizeMin+"-Infinity clear add");

// print output //
print("Image Name= ", imageName);
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
print("Date =", ""+year+"_"+month+"_"+dayOfMonth);
print("Timestamp =", ""+hour+"_"+minute+"_"+second);
print("Number Of Object Detected = ", roiManager("count"));
print("Length Of Selection (pixels) = ", maskValues.length);
print("Threshold for Smallest object (pixels) = ", objectSizeMin);
print("Position in image stack = ", "C"+channel+"_Z"+slice+"_T"+frame);

// print Image //
selectImage(profileID); run("Flatten"); rename(imageName+"_Profile"+""+year+"_"+month+"_"+dayOfMonth);
selectImage(profileID); close();
if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}














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
		array[i]=array[i]-(meanArray);
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

function stretchContrast(array,saturationPercentile) {
	array2=Array.copy(array);
	array2=Array.sort(array2); //Ascending  sort //
	lowerPercentile=array2[saturationPercentile/100*array2.length];

	array2=Array.reverse(Array.sort(array2));//descending  sort //
	upperPercentile=array2[saturationPercentile/100*array2.length];

	for (i = 0; i < array.length; i++) {
		array[i]=(array[i]-lowerPercentile)/upperPercentile;
		if (array[i]<0) {array[i]=0;}
		if (array[i]>1) {array[i]=1;}
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
		array2[i]=array[i]/windowAverage;
		if (array2[i]<0) {array2[i]=0;}
	}
	// local contrast (leading edge) //
		for (i = 0; i < rollingRadius; i++) {
			windowAverage=0; 
			for (j = 0; j < rollingRadius; j++) {
				windowAverage=windowAverage+array[i+j];
			}
			windowAverage=windowAverage/(rollingRadius);
			array2[i]=array[i]/windowAverage;
			if (array2[i]<0) {array2[i]=0;}
	}

	// local contrast (trailing edge) //
		for (i = array.length-rollingRadius; i < array.length; i++) {
			windowAverage=0; 
			for (j = 0; j < rollingRadius; j++) {
				windowAverage=windowAverage+array[i-j];
			}
			windowAverage=windowAverage/(rollingRadius);
			array2[i]=array[i]/windowAverage;
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
