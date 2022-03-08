while (selectionType()<0 ) {waitForUser("make Line Selection on channel to be quantified");}
refineLineSelection(9);
getSelectionCoordinates(xpoints, ypoints);
run("Select None");
imageID=getImageID();
imageName=getTitle();
if(isOpen("Log")){selectWindow("Log"); run("Close");}


// getting signal and converting to masks for channel 1 //
run("Select None"); channel=1; slice=1; frame=1; 
Stack.getDimensions(width, height, channels, slices, frames);
if(channels>1){
	channel1=getNumber("Channel #1 to process", 1);
	channel2=getNumber("Channel #2 to process", 2);
	selectImage(imageID); Stack.setChannel(channel1);
} 
run("Duplicate...", " "); imageID2=getImageID(); // duplicating current frame //
makeSelection("polyline", xpoints, ypoints); 
maskValues=getProfile(); // getting line profile
selectImage(imageID2); close();
setForegroundColor(255, 0, 0); call("ij.gui.ImageWindow.setNextLocation", 0, 0); newImage("Processing Image", "RGB white", 1200, 150, 1);  setFont("SansSerif", 50, "bold");  y = 50; x= 10; drawString("Processing Channel 1...", x, y);
punctaImage1=findPuncta(maskValues,50); // finds puncta from an array of gray values and returns a binarized image of height 50 with masked puncta indicated as vertical lines//
selectImage(punctaImage1); rename("channel1Profile_"+imageName);
if (isOpen("Processing Image")) {selectWindow("Processing Image");close();}




if(channels>1){ // getting signal and converting to masks for channel 2 //
	proceed=getBoolean("Proceed to next channel", "Yes", "Exit" );
	if (proceed==1) { 
	selectImage(imageID); run("Select None");
	Stack.setChannel(channel2); run("Duplicate...", " "); imageID2=getImageID(); // duplicating current frame //
	makeSelection("polyline", xpoints, ypoints); 
	maskValues=getProfile(); // getting line profile
	selectImage(imageID2); close();
	setForegroundColor(255, 0, 0); call("ij.gui.ImageWindow.setNextLocation", 0, 0); newImage("Processing Image", "RGB white", 1200, 150, 1);  setFont("SansSerif", 50, "bold");  y = 50; x= 10; drawString("Processing Channel 2...", x, y);
	punctaImage2=findPuncta(maskValues, 50); // finds puncta from an array of gray values and returns a binarized image of height 50 with masked puncta indicated as vertical lines //
	selectImage(punctaImage2); rename("channel2Profile"+imageName);
	}
}
if (isOpen("Processing Image")) {selectWindow("Processing Image");close();}



selectImage(imageID); makeSelection("polyline", xpoints, ypoints); // restore selection for next use //



// count puncta in image 1 //
if(isOpen("ROI Manager")){selectWindow("ROI Manager"); run("Close");}
selectImage(punctaImage1); setOption("BlackBackground", true); run("Convert to Mask"); run("Analyze Particles...", "size="+0+"-Infinity clear add");
print("---------"); print("Image Name= ", getTitle());  print("Number Of Object Detected = ", roiManager("count")); print("Length Of Selection (pixels) = ", getWidth()); // print output //
if(isOpen("ROI Manager")){selectWindow("ROI Manager"); run("Close");}




// count puncta in image 2 (if user wanted) //
if(isOpen("ROI Manager")){selectWindow("ROI Manager"); run("Close");}
if(channels>1){if (proceed==1) {
	selectImage(punctaImage2); setOption("BlackBackground", true); run("Convert to Mask"); run("Analyze Particles...", "size="+0+"-Infinity clear add");
	print("---------");print("Image Name= ", getTitle());  print("Number Of Object Detected = ", roiManager("count")); print("Length Of Selection (pixels) = ", getWidth()); // print output //
}
if(isOpen("ROI Manager")){selectWindow("ROI Manager"); run("Close");}




// compare puncta colocalization (if user wanted) //
percentOverlap=25;
if(channels>1){if (proceed==1) {
	
	//////////// objects in channel 1 that are positive for channel2 /////////
	selectImage(punctaImage1); setOption("BlackBackground", true); run("Convert to Mask"); run("Analyze Particles...", "size="+0+"-Infinity clear add");
	positiveObjects_Channel1=0;
	selectImage(punctaImage1); run("Duplicate...", " "); run("RGB Color"); punctaImage1_RGB=getImageID(); // making a duplicate for coloring positive objects 
	n = roiManager('count');
	for (i = 0; i < n; i++) {
		selectImage(punctaImage2);	
    	roiManager('select', i);
    	if (getValue("Mean")>255*percentOverlap/100){// if and object is positive 
    		positiveObjects_Channel1=positiveObjects_Channel1+1; // count the positive object
    		selectImage(punctaImage1_RGB); 	roiManager('select', i); setForegroundColor(255, 0, 0); roiManager("Fill"); // color the positive object 
    	}
    }
    print("---------"); print("objects in channel 1 that are positive for channel 2");  print("Percent of positive objects Detected = ", positiveObjects_Channel1/roiManager("count")*100); // print output //
	if(isOpen("ROI Manager")){selectWindow("ROI Manager"); run("Close");}

	
	//////////// objects in channel 2 that are positive for channel 1 /////////
	selectImage(punctaImage2); setOption("BlackBackground", true); run("Convert to Mask"); run("Analyze Particles...", "size="+0+"-Infinity clear add");
	positiveObjects_Channel2=0;
	selectImage(punctaImage2); run("Duplicate...", " "); run("RGB Color"); punctaImage2_RGB=getImageID(); // making a duplicate for coloring positive objects 
	n = roiManager('count');
	for (i = 0; i < n; i++) {
		selectImage(punctaImage1);	
    	roiManager('select', i);
    	if (getValue("Mean")>255*percentOverlap/100){// if and object is positive 
    		positiveObjects_Channel2=positiveObjects_Channel2+1; // count the positive object
    		selectImage(punctaImage2_RGB); 	roiManager('select', i); setForegroundColor(255, 0, 0); roiManager("Fill"); // color the positive object 
    	}
    }
	print("---------"); print("objects in channel 2 that are positive for channel 1");  print("Percent of positive objects Detected = ", positiveObjects_Channel2/roiManager("count")*100); // print output //
	if(isOpen("ROI Manager")){selectWindow("ROI Manager"); run("Close");}
	
	
	selectImage(punctaImage1);	close();  selectImage(punctaImage2);	close(); 
    
}}
selectWindow("Log"); saveAs("Text", getDirectory("downloads")+"Results of "+imageName+".txt");
run("Text File... ", "open=["+getDirectory("downloads")+"Results of "+imageName+".txt]"); 
if(isOpen("Log")){selectWindow("Log"); run("Close");}















































function findPuncta(arrayOfGrayValues,heightOfProfile) { 
	// finds puncta from an array of gray values and returns a binarized image of height "heightOfProfile" with masked puncta indicated as vertical lines //
	maskValues=stretchContrast(arrayOfGrayValues,1); // stretches contrast to 0 and 1 with 1% over and under saturation
	maskValues=localContrast1D(maskValues,20); // divides each number with a rolling average window of 20
	
	
	// getting thresholding values //
	Plot.create("Plot for setting threshold", "Length", "Intensities", Array.getSequence(maskValues.length), maskValues); Plot.show(); // show user plot of array to judge threshold
	Array.getStatistics(maskValues, min, max, mean, stdDev); maskThresholdGuess=maxOf(mean+(1*stdDev), 1.5); // Guess of threshold //
	maskThreshold=getNumber("Threshold For Masking", maskThresholdGuess); // Get Thresholding parameters from user //
	objectSizeMin=getNumber("Minimum length of object", 3); // Get Thresholding parameters from user //
	objectSizeMax=getNumber("Max length of object", 20); // Get Thresholding parameters from user //
	selectWindow("Plot for setting threshold"); run("Close"); // Get Thresholding parameters from user //
	maskValues=makeMask1D(maskValues, maskThreshold); // binarizes profile to 0 and 1
	
	
	// put mask values into image to detect objects //
	heightOfProfile=50;
	for (i = 1; i < maskValues.length; i++) {maskValues[i]=maskValues[i]*255;}
	newImage("profile_"+floor(random*1000), "8-bit black", maskValues.length, heightOfProfile, 1); profileID=getImageID();
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

	// return profile image //
	return profileID;
}
















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
	// remove bottom saturation percentile //
	array2=Array.copy(array);
	array2=Array.sort(array2); //Ascending  sort //
	lowerPercentile=array2[saturationPercentile/100*array2.length]; // this is the lower percentile //
	for (i = 0; i < array.length; i++) { array[i]=(array[i]-lowerPercentile);} // negating lower percentile //
	for (i = 0; i < array.length; i++) { if (array[i]<0) {array[i]=0;}} // converting negative numbers to zero //



	// saturate upper percentile //
	array2=Array.copy(array);
	array2=Array.reverse(Array.sort(array2));//descending  sort //
	upperPercentile=array2[saturationPercentile/100*array2.length]; // this is the upper percentile //
	for (i = 0; i < array.length; i++) {array[i]=array[i]/upperPercentile;} // dividing everything by the upper percentile //
	for (i = 0; i < array.length; i++) {if (array[i]>1) {array[i]=1;}} // converting numbers more than 1 to 1
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






function refineLineSelection(searchRadius){
	setLineWidth(searchRadius);
	run("To Selection");
	run("Fit Spline");
	run("Interpolate", "interval=1 smooth");
	getSelectionCoordinates(xpoints, ypoints);
	getSelectionCoordinates(xpointsCorrected, ypointsCorrected);

	// get threshold //
	intensities=getProfile();
	Array.getStatistics(intensities, min, max, meanIntensity, stdDev);
	threshold=meanIntensity;

	//refining selection //
	for (i = searchRadius; i < xpoints.length-searchRadius; i++) {
		makeLine(xpoints[i-searchRadius], ypoints[i-searchRadius], xpoints[i+searchRadius], ypoints[i+searchRadius]);
		run("Rotate...", "  angle=90");
		run("Interpolate", "interval=1 smooth");
		getSelectionCoordinates(xpointsProfile, ypointsProfile);
		profile=getProfile();
		maxima=Array.findMaxima(profile, 1); 
		if (lengthOf(maxima)>0) {
			maxima=maxima[0];
		} else {maxima=0;}

		if (profile[maxima]>threshold){xpointsCorrected[i]=xpointsProfile[maxima]; ypointsCorrected[i]=ypointsProfile[maxima];}
		if (profile[maxima]<=threshold) {xpointsCorrected[i]=xpoints[i]; ypointsCorrected[i]=ypoints[i];}
	}
	makeSelection("polyline", xpointsCorrected, ypointsCorrected);
	run("Interpolate", "interval=10 smooth");
	run("Properties... ", "  width="+minOf(searchRadius,5));
	
}
