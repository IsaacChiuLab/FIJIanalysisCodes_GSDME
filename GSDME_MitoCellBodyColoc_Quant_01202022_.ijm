objectSize=9; //input approx object size in pixels
thresholdStringency = 6;// input threshold stringency (anywhere between 0-9.99)


// opening image if not open already 
if (nImages<1) {
	filepath=File.openDialog("Select an image File");
	run("Bio-Formats Importer", "open=["+filepath+"] color_mode=Default view=Hyperstack stack_order=XYCZT");
}

// whether to run on single slice or z-stack //
Stack.getPosition(channel, slice, frame);
//run("Duplicate...", "duplicate frames="+frame); // to run the macro on z-stack
run("Duplicate...", "duplicate slices="+slice+" frames="+frame); // to run the macro on single slice
imageID=getImageID();imageName=getInfo("image.filename");
Stack.getDimensions(width, height, channels, slices, frames);

// max projecting images if Z-slices are detected //
if (slices>1) {	
	run("Z Project...", "projection=[Average Intensity]");
	imgOrigProjectedID=getImageID(); selectImage(imageID); close();
	imageID=imgOrigProjectedID;
}

//ask user to draw cell outline//
setTool(2); 
for (i = 1; i <= nSlices; i++) {setSlice(i); 
    resetMinAndMax(); run("Enhance Contrast", "saturated=0.1");
}
waitForUser("Draw cell periphery and press OK");
while (selectionType()==-1) {waitForUser("Draw cell periphery and press OK");}
getSelectionCoordinates(xpoints, ypoints);
run("Select None");

//ask user to draw background area //
text="Mark an area that represents background and press OK";
text=text+"\n ";
text=text+"\n Area can be of any size but close to the cell selected";
setTool(3); waitForUser(text); while (selectionType()==-1) {waitForUser(text);}
getSelectionCoordinates(xpointsBackground, ypointsBackground);
run("Select None");

// duplicate mito channel//
selectImage(imageID);
Stack.setChannel(1);
run("Duplicate...", " ");

// remove background //
run("Subtract Background...", "rolling="+objectSize*2+" slice"); 

// stretch contrast and convert to 8 bit //
max=getValue("Mean")+2*getValue("StdDev");
run("Subtract...", "value="+getValue("Median")+getValue("StdDev")+" slice");
run("Enhance Contrast", "saturated=0.1"); getMinAndMax(min, max);
run("Multiply...", "value="+(pow(2, bitDepth())-1)/max+" slice"); resetMinAndMax();
run("8-bit");

// threshold //
threshold=round((pow(2, bitDepth())-1)*0.1*thresholdStringency);
run("Subtract...", "value="+threshold+" slice");
run("Multiply...", "value="+(pow(2, bitDepth())-1)+" slice");
run("8-bit");
run("Set Scale...", "distance=0 known=0 unit=pixel");
maskID=getImageID();

// clearing mask //
run("Options...", "iterations=1 count=1 black do=Erode");
run("Options...", "iterations=1 count=1 black do=Erode");
run("Options...", "iterations=1 count=1 black do=Dilate");
run("Options...", "iterations=1 count=1 black do=Dilate");
makeSelection("polygon", xpoints, ypoints);
run("Clear Outside");
run("Analyze Particles...", "size="+objectSize+"-infinity clear add");
selectImage(maskID); close();

// duplicate GFP channel // 
selectImage(imageID);
Stack.setChannel(2);
run("Duplicate...", " ");

// remove background and stretch contrast//
makeSelection("polygon", xpointsBackground, ypointsBackground); 
background=getValue("Median");
run("Select None");
run("Subtract...", "value="+background+" slice"); resetMinAndMax();
run("Multiply...", "value="+(pow(2, bitDepth())-1)/getValue("Max")+" slice"); resetMinAndMax();
run("Enhance Contrast", "saturated=0.35");

// total area of mitochondria and total GFP signal //
GFPonMito=0;
mitoArea=0;
for (i = 0; i < roiManager("count"); i++) {
    roiManager("select", i);
    GFPonMito=GFPonMito+getValue("Mean")*getValue("Area");
    mitoArea=mitoArea+getValue("Area");
}


// total cytosolic signal and area //
run("Select None");
makeSelection("polygon", xpoints, ypoints);
totalGFPsignal=getValue("Mean")*getValue("Area");
totalArea=getValue("Area");
ratio=(GFPonMito/mitoArea)/((totalGFPsignal-GFPonMito)/(totalArea-mitoArea));

// showing image//
run("Select None");
resetMinAndMax(); 
run("Enhance Contrast", "saturated=0.1");
run("Remove Outliers...", "radius=1 threshold=0 which=Bright");
run("RGB Color");
makeSelection("polygon", xpoints, ypoints);
run("Fit Spline"); 
setForegroundColor(255, 255, 255);
run("Draw", "slice");
for (i = 0; i < roiManager("count"); i++) {
    roiManager("select", i);
    setForegroundColor(255, 0, 0);
    run("Draw", "slice");
}


// printing results //
selectImage(imageID); close();
if (isOpen("Log")){close("Log");}
if (isOpen("ROI Manager")){close("ROI Manager");}
textWindowName="[results_"+imageName+"]";
run("Text Window...", "name="+textWindowName+" width=60 height=16 menu");
print(textWindowName, "\nFilename = "+ imageName);
print(textWindowName, "\nTotal GFP signal on mitochondria = "+ GFPonMito);
print(textWindowName, "\nMitochondrial area = "+ mitoArea);
print(textWindowName, "\nTotal GFP signal outside mitochondria= "+ totalGFPsignal-GFPonMito);
print(textWindowName, "\nCytosol area= "+ totalArea-mitoArea);
print(textWindowName, "\nmean mitochondrial intensity : mean cytosolic intensity= "+ ratio);
showMessage("Please save the Log file before proceeding to next cell");
