// Reopen and inspect one saved field; measurements are never recomputed.
requires("1.54g");
var REVIEW_LABEL_SIZE=14, REVIEW_SHOW_IDS=0, REVIEW_ZOOM=400, previewIDs=newArray(0);
reviewFolder=getDirectory("Choose one field folder containing *_review.tif");
reviewFiles=getFileList(reviewFolder);Array.sort(reviewFiles);
for (reviewFile=0;reviewFile<reviewFiles.length;reviewFile++) if (endsWith(reviewFiles[reviewFile],"_review.tif")) {
    open(reviewFolder+reviewFiles[reviewFile]);reviewOne=newArray(1);reviewOne[0]=getImageID();previewIDs=Array.concat(previewIDs,reviewOne);
}
if (previewIDs.length==0) exit("No *_review.tif files found in this folder.");
applyReviewLabels();inspectPreview();
// Leave the reopened review images open for further inspection.
// Display controls shared by calibration previews and the saved-field reviewer.
function inspectPreview() {
    reviewActive=1;
    while (reviewActive) {
        waitForUser("Review - zoom and pan", "Click an image, then use the magnifier or + / - to zoom.\nIDs are an independent overlay, not image pixels.\nClick OK for ID visibility, font size, or locating a Cell_ID.\nGreen=positive; red=negative; orange=excluded; cyan=DAPI included.");
        Dialog.create("Review controls");
        Dialog.addChoice("Action",newArray("Finish review","Locate cell by ID","Show cell IDs","Hide cell IDs","Label size and locate zoom","Show all marks","Hide all marks"),"Finish review");
        Dialog.show();reviewAction=Dialog.getChoice();
        if (reviewAction=="Finish review") reviewActive=0;
        else if (reviewAction=="Show cell IDs") {REVIEW_SHOW_IDS=1;applyReviewLabels();setReviewOutlines(1);}
        else if (reviewAction=="Hide cell IDs") {REVIEW_SHOW_IDS=0;applyReviewLabels();}
        else if (reviewAction=="Show all marks") setReviewOutlines(1);
        else if (reviewAction=="Hide all marks") setReviewOutlines(0);
        else if (reviewAction=="Label size and locate zoom") {
            Dialog.create("Review appearance");
            Dialog.addNumber("ID font size (screen pixels)",REVIEW_LABEL_SIZE);
            Dialog.addNumber("Locate zoom (%)",REVIEW_ZOOM);
            Dialog.show();reviewFont=Dialog.getNumber();reviewMagnification=Dialog.getNumber();
            if (isNaN(reviewFont)||reviewFont<6||reviewFont>72||isNaN(reviewMagnification)||reviewMagnification<25||reviewMagnification>3200)
                showMessage("Review appearance","Use font size 6-72 and locate zoom 25-3200%.");
            else {REVIEW_LABEL_SIZE=round(reviewFont);REVIEW_ZOOM=reviewMagnification;applyReviewLabels();}
        } else if (reviewAction=="Locate cell by ID") {
            reviewCell=getNumber("Cell_ID from cells.csv (1-based)",1);
            if (isNaN(reviewCell)||reviewCell<1||reviewCell!=floor(reviewCell)) showMessage("Locate cell","Enter a positive integer Cell_ID.");
            else locateReviewCell(reviewCell);
        }
    }
}

function applyReviewLabels() {
    for (reviewImage=0;reviewImage<previewIDs.length;reviewImage++) if (isOpen(previewIDs[reviewImage])) {
        selectImage(previewIDs[reviewImage]);
        if (Overlay.size>0) {
            Overlay.useNamesAsLabels(true);Overlay.setLabelColor("white");
            // A fixed screen font remains legible without covering the cell at high zoom.
            Overlay.setLabelFontSize(REVIEW_LABEL_SIZE,"bold back");
            // setLabelFontSize enables labels: apply the requested visibility LAST.
            Overlay.drawLabels(REVIEW_SHOW_IDS);Overlay.selectable(false);
        }
    }
}

function setReviewOutlines(visible) {
    for (reviewImage=0;reviewImage<previewIDs.length;reviewImage++) if (isOpen(previewIDs[reviewImage])) {
        selectImage(previewIDs[reviewImage]);
        if (Overlay.size>0) {if (visible) Overlay.show;else Overlay.hide;}
    }
}

function locateReviewCell(cellID) {
    reviewFound=0;
    for (reviewImage=0;reviewImage<previewIDs.length;reviewImage++) if (isOpen(previewIDs[reviewImage])) {
        selectImage(previewIDs[reviewImage]);
        // Every new review has exactly one ROI for each Cell_ID, including excluded nuclei.
        if (cellID<=Overlay.size) {
            Overlay.activateSelection(cellID-1);
            if (Roi.getName==d2s(cellID,0)) {
                getSelectionBounds(reviewX,reviewY,reviewW,reviewH);run("Select None");
                Overlay.show;
                run("Set... ","zoom="+REVIEW_ZOOM+" x="+(reviewX+reviewW/2)+" y="+(reviewY+reviewH/2));
                // A separate rectangle highlights the location without editing an overlay ROI.
                reviewLeft=maxOf(0,reviewX-2);reviewTop=maxOf(0,reviewY-2);
                makeRectangle(reviewLeft,reviewTop,minOf(getWidth()-reviewLeft,reviewW+4),minOf(getHeight()-reviewTop,reviewH+4));
                reviewFound++;
            } else run("Select None");
        }
    }
    if (reviewFound==0) showMessage("Locate cell","Cell_ID not found in the open review images. Check cells.csv for this field.");
}

function closePreviews() {
    for (reviewImage=0;reviewImage<previewIDs.length;reviewImage++) if (isOpen(previewIDs[reviewImage])) {
        selectImage(previewIDs[reviewImage]);
        // These windows are disposable review copies; TIFFs already retain the saved overlays.
        setOption("Changes",false);close();
    }
    previewIDs=newArray(0);
}
