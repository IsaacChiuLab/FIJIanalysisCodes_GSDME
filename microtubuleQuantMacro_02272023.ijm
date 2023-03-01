////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
// getting thresholds from user //
microtubuleThreshold=500; // Increase this to increase detection of tubules. Decrease if noisy
depolymerizedMtThreshold=5000;  // Decrease this to increase detection of depol MTs. Increase if noisy
tubuleThickness=3;
minArea=3;
circularityThreshold=0.3;
tubularityThreshold=0.1;  // Increase this to increase detection of tubules. Decrease if noisy
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

// asking user to open image if no images are open (one image at a time)//
if (nImages>0) {
quantifyTUJ1integrity(getImageID() , microtubuleThreshold, depolymerizedMtThreshold, tubuleThickness, minArea, circularityThreshold,tubularityThreshold); 
}
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

// proces whole directory //
if (nImages<1){
	regexToLookFor="_RAW_ch03_max.tif";
	dir=getDirectory("Choose Directory"); filelist = getFileList(dir); 
	for (i = 0; i < lengthOf(filelist); i++) {
 	   if (endsWith(filelist[i], regexToLookFor)) {open(dir + File.separator + filelist[i]);
 	   quantifyTUJ1integrity(getImageID() , microtubuleThreshold, depolymerizedMtThreshold, tubuleThickness, minArea, circularityThreshold,tubularityThreshold); 
	}}
}






function quantifyTUJ1integrity(imageID, microtubuleThreshold, depolymerizedMtThreshold, tubuleThickness, minArea, circularityThreshold, tubularityThreshold){
	
	selectImage(imageID); imageName=getInfo("image.filename"); imageDirectory=getInfo("image.directory"); 
	randomTempName=floor(random*1000);
	// run flat field correction //
	selectImage(imageID); 
	radius=floor(maxOf(getHeight(), getWidth())/4); 
	run("Duplicate...", "duplicate"); avgImageID=getImageID();
	run("Mean...", "radius="+radius+" stack"); run("32-bit"); 
	run("Divide...", "value="+getValue("Max Raw"));
	imageCalculator("Divide stack", imageID, avgImageID);
	selectImage(avgImageID); close();
	
	// gentle background removal correction //
	run("Subtract Background...", "rolling=45 slice"); 
	
	// stretch contrast //
	minIntensity=getValue("Min"); run("Subtract...", "value="+minIntensity+" slice");
	resetMinAndMax; run("Enhance Contrast", "saturated=0.01"); getMinAndMax(min, max);
	run("Multiply...", "value="+(pow(2, bitDepth())-1)/max+" slice"); resetMinAndMax;
	
	
	// threshold de-polymerized microtubules //
	selectImage(imageID); run("Duplicate...", " "); depolMTimageID=getImageID();
	setThreshold(depolymerizedMtThreshold, pow(2, bitDepth())-1, "raw"); 
	run("Convert to Mask");
	
	// remove small particles //
	selectImage(depolMTimageID);
	run("Analyze Particles...", "size=0-"+minArea+" pixel clear add");
	setForegroundColor(0, 0, 0);
	if (isOpen("ROI Manager")) {roiManager("deselect"); roiManager("Fill"); selectWindow("ROI Manager"); run("Close");}
	setOption("BlackBackground", true);  setOption("ScaleConversions", true);
	
	// remove tubules from image //
	selectImage(depolMTimageID); run("Close-");
	run("Analyze Particles...", "size="+0+"-infinity pixel circularity=0.00-"+circularityThreshold+" clear add");
	setForegroundColor(0, 0, 0);
	if (isOpen("ROI Manager")) {roiManager("deselect"); roiManager("Fill"); selectWindow("ROI Manager"); run("Close");}
	setOption("BlackBackground", true); run("Convert to Mask");
	
	// threshold all microtubules after harsh local gaussian //
	selectImage(imageID); run("Duplicate...", " "); polMTImageID=getImageID();
	run("Subtract...", "value="+microtubuleThreshold+" slice"); // simple background substraction
	run("Duplicate...", " "); run("Gaussian Blur...", "sigma="+tubuleThickness); imageBlurred=getImageID();
	imageCalculator("Subtract create", polMTImageID, imageBlurred); imageEdges=getImageID(); //gaussian local background substraction to highlight tubular structures
	selectImage(imageEdges); run("Subtract...", "value="+getValue("Min")+" slice"); // removing any remaining minimium intensity //
	
	selectImage(imageEdges);setThreshold(1, pow(2, bitDepth())-1, "raw");  run("Convert to Mask"); // Thresholding whatever fluoresence is left	
	selectImage(polMTImageID);close(); selectImage(imageBlurred); close(); // closing intermediate images //
	selectImage(imageEdges); polMTImageID=getImageID(); 
	
	// remove small objects from polMT image//
	if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}
	selectImage(polMTImageID); run("Analyze Particles...", "size="+0+"-"+minArea+" pixel circularity=0.00-"+1.00+" clear add");
	setForegroundColor(0, 0, 0);if (isOpen("ROI Manager")) {roiManager("deselect"); roiManager("Fill"); selectWindow("ROI Manager"); run("Close");}
	selectImage(polMTImageID); setOption("BlackBackground", true); setOption("ScaleConversions", true);
	selectImage(polMTImageID); run("Select None"); 
	
	
		
	// remove round objects from polMT image //
	if (isOpen("ROI Manager")) {selectWindow("ROI Manager"); run("Close");}
	selectImage(polMTImageID); run("Analyze Particles...", "size="+0+"-infinity pixel circularity="+tubularityThreshold+"-"+1+" clear add");
	setForegroundColor(0, 0, 0); if (isOpen("ROI Manager")) {roiManager("deselect"); roiManager("Fill"); selectWindow("ROI Manager"); run("Close");}
	selectImage(polMTImageID); setOption("BlackBackground", true); setOption("ScaleConversions", true);
	selectImage(polMTImageID); run("Select None"); 
	
	
	// Subtracting depolymerized microtubules from polMT image in case it is detected //
	imageCalculator("Subtract", polMTImageID,depolMTimageID); 
	
	
	// count total number of polymerized and depolymerized MTs //
	selectImage(depolMTimageID);totaldepolymerizedMtPixels=getValue("Mean Raw")*getHeight()*getWidth()/255;
	selectImage(polMTImageID); totalPolymerizedMtPixels=getValue("Mean Raw")*getHeight()*getWidth()/255;
	
	// create images for display //
	selectImage(polMTImageID);run("Green"); run("RGB Color"); rename(randomTempName+"_polMTImage"+imageName);
	selectImage(depolMTimageID);run("Red"); run("RGB Color"); rename(randomTempName+"_depolMTImage"+imageName);
	imageCalculator("Add create", polMTImageID,depolMTimageID); rename(randomTempName+"_classifiedMTImage"+imageName); // adding the images for easy visualization //
	selectImage(imageID); close(); selectImage(polMTImageID); run("Close"); selectImage(depolMTimageID); run("Close");
	
	// print results //
	Headings= "ImageName" +"	"+ "Polymerized MT pixels" +"	"+ "Depolymerized MT pixels" +"	"+ "microtubuleThreshold" +"	"+ "depolymerizedMtThreshold" +"	"+ "tubuleThickness" +"	"+ "minArea" +"	"+ "circularityThreshold" +"	"+ "tubularityThreshold";
	name = "[MT quants results]"; f = name;
	if(isOpen("MT quants results")==0){run("New... ", "name="+name+" type=Table"); 	print (f, "\\Headings:"+ Headings);}
	Measurements= imageName +"	"+ totalPolymerizedMtPixels +"	"+ totaldepolymerizedMtPixels +"	"+ microtubuleThreshold +"	"+ depolymerizedMtThreshold +"	"+ tubuleThickness +"	"+ minArea +"	"+ circularityThreshold +"	"+ tubularityThreshold;
	print (f, Measurements);	
	
	//Save classified image //
	classifiedMTImageName=replace(imageName, ".tif", "_classifiedMTImage.tif");
	selectWindow(randomTempName+"_classifiedMTImage"+imageName);
	saveAs(imageDirectory+classifiedMTImageName); //close();
}