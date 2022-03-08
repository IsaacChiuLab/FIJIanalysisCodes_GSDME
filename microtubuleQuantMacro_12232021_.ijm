
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

// getting thresholds from user (comment out the 64-67) for pro mode (using thresholds directly input into code)//
microtubuleThreshold=1500;
depolymerizedMtThreshold=16000;
tubuleThickness=3;
minArea=5;
circularityThreshold=0.1;
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////




// asking user to open image if no images are open //
if (nImages<1) {
	imagePath=File.openDialog("please select file");
	run("Bio-Formats", "open=["+imagePath+"]+ autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	run("Enhance Contrast", "saturated=0.35");
}

imageName=getInfo("image.filename");
StackImageID=getImageID();
randomTempName=floor(random*1000);
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
// asking user to process all open images or process single image //
if (nImages>1) {
	makeStack=getBoolean("process all open images together?", "yes", "single image");
	if (makeStack==1) {	run("Images to Stack", "name=MultipleImageStack title=[] use");}
	StackImageID=getImageID(); imageName=getTitle();
}

// run flat field correction //
radius=floor(maxOf(getHeight(), getWidth())/4);
selectImage(StackImageID); run("Duplicate...", "duplicate"); avgImageID=getImageID();
run("Mean...", "radius="+radius+" stack"); run("32-bit"); 
for (i = 1; i <= nSlices; i++) {setSlice(i); run("Divide...", "value="+getValue("Max Raw"));}
imageCalculator("Divide stack", StackImageID, avgImageID);
selectImage(avgImageID); close();


// stretching contrast in each image //
showText("Please Wait", "Please Wait \nthis dialog box will close automatically"); setBatchMode("hide");
for (zSliceNumber = 1; zSliceNumber <= nSlices; zSliceNumber++) {
	selectImage(StackImageID); 
	if (nSlices>1){setSlice(zSliceNumber);} 
	run("Subtract Background...", "rolling=45 slice"); // gentle background removal correction //
	minIntensity=getValue("Min"); run("Subtract...", "value="+minIntensity+" slice");
	maxIntensity=getMaxFluoresence(); run("Multiply...", "value="+65535/maxIntensity+" slice");
}
if (isOpen("Please Wait")) {selectWindow("Please Wait");run("Close");}
setBatchMode("exit and display");

////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

// getting thresholds from user //
microtubuleThreshold=askUserForThreshold("threshold for polymerized MTs (lower threshold)", StackImageID);
depolymerizedMtThreshold=askUserForThreshold("threshold for depolymerized MTs  (upper threshold)", StackImageID);
tubuleThickness=getNumber("tubuleThickness", 3);
minArea=5;
circularityThreshold=0.1;
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////




// initializing arrays //
depolymerizedToTotalRatio = newArray(nSlices);
depolymerizedToPolymerizedRatio=newArray(nSlices);
totaldepolymerizedMtPixelsFullStack=newArray(nSlices);
totalPolymerizedMtPixelsFullStack=newArray(nSlices);
totalMicrotubulePixelsFullStack = newArray(nSlices);
sliceLabel = newArray(nSlices);

////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
//saving pre-processed image stack to HDD (slow but prevents crashes) //

// calculations //
setBatchMode("hide");
selectImage(StackImageID); 
for (zSliceNumber = 1; zSliceNumber <= nSlices; zSliceNumber++) {
    // Go to Z-slice //
	selectImage(StackImageID); 
    if (nSlices>1){setSlice(zSliceNumber);} 
    Stack.getPosition(channel, slice, frame);
	
	// duplicating slice //
	selectImage(StackImageID);
	run("Duplicate...", " ");
	imageID=getImageID();


	// find number of pixels occupied by microtubules //
	selectImage(imageID);
	run("Duplicate...", " ");
	totalMTimageID=getImageID();
	thresholdImage(totalMTimageID, microtubuleThreshold, minArea);
	selectImage(totalMTimageID); run("Select None"); 
	totalMicrotubulePixels=getValue("Mean Raw")*getHeight()*getWidth()/255;

	// find number of pixels occupied by de-polymerized microtubules //
	selectImage(imageID);
	run("Duplicate...", " ");
	depolMTimageID=getImageID();
	thresholdImage(depolMTimageID, depolymerizedMtThreshold, minArea);
	removeTubesFromThresholdedImage(depolMTimageID,circularityThreshold);
	selectImage(depolMTimageID); run("Select None"); 
	totaldepolymerizedMtPixels=getValue("Mean Raw")*getHeight()*getWidth()/255;

	
	// find number of polymerized tubules in image //
	selectImage(imageID);
	polMTImageID=findTubules(imageID, microtubuleThreshold, minArea, circularityThreshold, tubuleThickness);
	selectImage(polMTImageID); run("Select None");
	imageCalculator("Subtract", polMTImageID,depolMTimageID); // Subtracting depolymerized microtubules in case it is detected 
	totalPolymerizedMtPixels=getValue("Mean Raw")*getHeight()*getWidth()/255;
	
	
	// create images for display //
	selectImage(polMTImageID);run("Green"); run("RGB Color"); rename(randomTempName+"_polMTImage"+imageName);
	selectImage(depolMTimageID);run("Red"); run("RGB Color"); rename(randomTempName+"_depolMTImage"+imageName);
	selectImage(totalMTimageID); close();
	selectImage(imageID); close();
	imageCalculator("Add create", polMTImageID,depolMTimageID); rename(randomTempName+"_classifiedMTImage"+imageName+slice); // adding the images for easy visualization //
	selectImage(polMTImageID); run("Close");
	selectImage(depolMTimageID); run("Close");

	
	// save images for display (to opened later and appended) //
	tempDir=getDirectory("temp")+"tuj1Quant"+File.separator;
	//selectWindow(randomTempName+"_classifiedMTImage"+imageName); save(tempDir+getTitle()); close();
	
	// Output results as arrays //
	depolymerizedToTotalRatio[zSliceNumber-1]=totaldepolymerizedMtPixels/(totaldepolymerizedMtPixels+totalPolymerizedMtPixels);
	depolymerizedToPolymerizedRatio[zSliceNumber-1]=totaldepolymerizedMtPixels/totalPolymerizedMtPixels;
	totalMicrotubulePixelsFullStack[zSliceNumber-1]=totalMicrotubulePixels;
	selectImage(StackImageID); sliceLabel[zSliceNumber-1] = getInfo("slice.label");
	totaldepolymerizedMtPixelsFullStack[zSliceNumber-1]=totaldepolymerizedMtPixels;
	totalPolymerizedMtPixelsFullStack[zSliceNumber-1]=totalPolymerizedMtPixels;

	// remove temp files (free up memory) (every 10 images)//
	if ((zSliceNumber/10) == round(zSliceNumber/10)) {run("Collect Garbage");}

	// reslecting original stack for next loop //
	selectImage(StackImageID); 
}

setBatchMode("exit and display");




run("Images to Stack", "name="+randomTempName+"_classifiedMTImage title="+randomTempName+"_classifiedMTImage"+imageName+" use");
imageInfo=newArray("imageName",imageName, "", "", "depolymerizedMtThreshold",depolymerizedMtThreshold, "", "", "microtubuleThreshold",microtubuleThreshold,  "", "", "tubuleThickness",tubuleThickness);
Array.show(totalMicrotubulePixelsFullStack, totalPolymerizedMtPixelsFullStack, totaldepolymerizedMtPixelsFullStack, depolymerizedToPolymerizedRatio, depolymerizedToTotalRatio, sliceLabel,imageInfo );
Table.rename("Arrays", imageName+"_quants");











// get 99.995 percent fluoresence //
function getMaxFluoresence() {
getHistogram(values, counts,65536);
nPixels=getValue("Area raw");
countCutOff=99.995*nPixels/100;
cumCounts=newArray(counts.length);
cumCounts[0]=counts[0];
for (i = 1; i < counts.length; i++) {
	cumCounts[i]=counts[i]+cumCounts[i-1];
	if (cumCounts[i]<countCutOff){threshold=i;}
}
return threshold














/////////////////////////////////////////////
function askUserForThreshold(textToDisplay, imageID) { 
	//interactively get threshold 
	repeat=1;
	getStatistics(area, mean, min, max, std, histogram); background=mean;
	while (repeat==1) {
		selectImage(imageID); run("Select None"); 
		run("Duplicate...", " "); sliceID=getImageID(); 
		setThreshold(background, pow(2, bitDepth())-1);
		background1=getNumber(textToDisplay, background);
		selectImage(sliceID); close();
		if (background1==background) {repeat=0;}
		background=background1;
		if (isOpen("Please Confirm")) {selectWindow("Please Confirm");close();}
		call("ij.gui.ImageWindow.setNextLocation", 0, 0); newImage("Please Confirm", "RGB white", 450, 300, 1); 
		setFont("SansSerif", 20, "bold");  y = 30; x= 10; drawString("Please confirm threshold", x, y); drawString("This message will close automatically", x, 2*y);
	}
	if (isOpen("Please Confirm")) {selectWindow("Please Confirm");close();}
	return background
}








// thresholding //
function thresholdImage(imageID, threshold, minArea){
	setBatchMode("hide");	
	selectImage(imageID);
	for (x = 0; x < getWidth(); x++) { for (y = 0; y < getHeight(); y++) {selectImage(imageID);
		if (getPixel(x, y)>threshold) { setPixel(x, y, pow(2, bitDepth())-1);}
		if (getPixel(x, y)<=threshold) { setPixel(x, y, 0);}
	}}
	setBatchMode("exit and display");
	run("8-bit"); setOption("BlackBackground", true);  setOption("ScaleConversions", true);

	// getting rid of noise pixels //
	if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}
	run("Analyze Particles...", "size=0-"+minArea+" pixel clear add");
	setForegroundColor(0, 0, 0);
	if (isOpen("ROI Manager")) {
	roiManager("deselect"); roiManager("Fill"); selectWindow("ROI Manager"); run("Close");}
	setOption("BlackBackground", true);  setOption("ScaleConversions", true);
	selectImage(imageID); run("Select None"); 
}



/// function remove tubular sturctures from thresholded image //
function removeTubesFromThresholdedImage(imageID,circularityThreshold) {
	selectImage(imageID); run("Close-");
	setOption("BlackBackground", true); run("Convert to Mask"); 
	if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}
	run("Analyze Particles...", "size="+0+"-infinity pixel circularity=0.00-"+circularityThreshold+" clear add");
	setForegroundColor(0, 0, 0);
	if (isOpen("ROI Manager")) {
	roiManager("deselect"); roiManager("Fill"); selectWindow("ROI Manager"); run("Close");}
	setOption("BlackBackground", true); run("Convert to Mask");
	selectImage(imageID); run("Select None"); 
}




/////////////////////////////////////////////
function findTubules(imageID, background, minArea, circularityThreshold, tubuleThickness) { 
	// threshold out tubular structures in an image//
	
	
	// gaussian deconvolution //
	selectImage(imageID);  run("Duplicate...", " "); imageOrig=getImageID();
	run("Subtract...", "value="+background+" slice"); // simple background substraction
	run("Duplicate...", " "); run("Gaussian Blur...", "sigma="+tubuleThickness); imageBlurred=getImageID();
	imageCalculator("Subtract create", imageOrig, imageBlurred); imageEdges=getImageID();
	selectImage(imageOrig);close(); selectImage(imageBlurred); close();
	
	
	// stretch contrast //
	selectImage(imageEdges);
	minIntensity=getValue("Min"); maxIntensity=getValue("Max");
	run("Subtract...", "value="+minIntensity+" slice");
	run("Multiply...", "value="+65535/(maxIntensity-minIntensity)+" slice");
	
	
	// threhsolding //
	setBatchMode("hide");
	for (x = 0; x < getWidth(); x++) { for (y = 0; y < getHeight(); y++) {
		selectImage(imageEdges);
		if (getPixel(x, y)>0) { setPixel(x, y, pow(2, bitDepth())-1);}
	}}
	run("8-bit"); setOption("BlackBackground", true);  setOption("ScaleConversions", true);
	setBatchMode("exit and display");
	
	
	
	// remove small objects //
	if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}
	selectImage(imageEdges); run("Analyze Particles...", "size="+0+"-"+minArea+" pixel circularity=0.00-"+1.00+" clear add");
	 setForegroundColor(0, 0, 0);
	if (isOpen("ROI Manager")) {roiManager("deselect"); roiManager("Fill"); selectWindow("ROI Manager"); run("Close");}
	selectImage(imageEdges); setOption("BlackBackground", true); setOption("ScaleConversions", true);
	selectImage(imageEdges); run("Select None"); 
		
	// remove round objects (fast and crude) //
	if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}
	selectImage(imageEdges); run("Analyze Particles...", "size="+0+"-infinity pixel circularity="+circularityThreshold+"-"+1+" clear add");
	 setForegroundColor(0, 0, 0);
	if (isOpen("ROI Manager")) {roiManager("deselect"); roiManager("Fill"); selectWindow("ROI Manager"); run("Close");}
	selectImage(imageEdges); setOption("BlackBackground", true); setOption("ScaleConversions", true);
	selectImage(imageEdges); run("Select None"); 
	
	// remove round objects (slow and accurate) //
	if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}
	selectImage(imageEdges); run("Analyze Particles...", "size="+0+"-infinity pixel circularity=0.00-"+1+" clear add");
	showText("Please Wait", "Please Wait \nthis dialog box will close automatically"); setBatchMode("hide");
	n = roiManager('count'); for (i = 0; i < n; i++) {
		selectImage(imageEdges);
	    roiManager('select', i); 

		//Area1= getValue("Area"); run("Enlarge...", "enlarge=-"+tubuleThickness+" pixel"); Area2= getValue("Area"); 
		//if (Area2/Area1>0.3){roiManager('select', i); roiManager("Fill"); }
	    
		
		//run("Enlarge...", "enlarge=10 pixel");run("Enlarge...", "enlarge=-10 pixel");
	    //if (getValue("Circ.")>0.75){roiManager('select', i); roiManager("Fill"); }
	}
	setBatchMode("exit and display");
	selectImage(imageEdges); run("Select None"); 
	if (isOpen("Please Wait")) {selectWindow("Please Wait");run("Close");}
	if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");} 
	selectImage(imageEdges); setOption("BlackBackground", true); setOption("ScaleConversions", true);
	return imageEdges
}


