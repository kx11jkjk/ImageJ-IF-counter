// Simple batch counting: first make and confirm a calibration for this project.
// Marker names, filename channels and parameters come from that calibration_confirmed.txt.
// Input filenames: sample-channel-field.tif (or .tiff), for example S01-yellow-1.tif.
// USER SETTING: "ALL", or positive AND targets separated by semicolons.
// Example: "CD8+GZMK;CD8+GZMK+TIM3". Unlisted markers are unrestricted.
var COMBINATIONS="ALL";
var SAVE_REVIEW_IMAGES=1; // Set 0 for tables only.
var previewIDs=newArray(0);
// END USER SETTINGS. All populations can overlap; do not sum their counts.
// Review display only; these settings never change segmentation or counts.
var REVIEW_LABEL_SIZE=14, REVIEW_SHOW_IDS=0, REVIEW_ZOOM=400;
requires("1.54g");
var REVIEW_TOOLS_SOURCE="// Reopen and inspect one saved field; measurements are never recomputed.\nrequires(\"1.54g\");\nvar REVIEW_LABEL_SIZE=14, REVIEW_SHOW_IDS=0, REVIEW_ZOOM=400, previewIDs=newArray(0);\nreviewFolder=getDirectory(\"Choose one field folder containing *_review.tif\");\nreviewFiles=getFileList(reviewFolder);Array.sort(reviewFiles);\nfor (reviewFile=0;reviewFile<reviewFiles.length;reviewFile++) if (endsWith(reviewFiles[reviewFile],\"_review.tif\")) {\n    open(reviewFolder+reviewFiles[reviewFile]);reviewOne=newArray(1);reviewOne[0]=getImageID();previewIDs=Array.concat(previewIDs,reviewOne);\n}\nif (previewIDs.length==0) exit(\"No *_review.tif files found in this folder.\");\napplyReviewLabels();inspectPreview();\n// Leave the reopened review images open for further inspection.\n// Display controls shared by calibration previews and the saved-field reviewer.\nfunction inspectPreview() {\n    reviewActive=1;\n    while (reviewActive) {\n        waitForUser(\"Review - zoom and pan\", \"Click an image, then use the magnifier or + / - to zoom.\\nIDs are an independent overlay, not image pixels.\\nClick OK for ID visibility, font size, or locating a Cell_ID.\\nGreen=positive; red=negative; orange=excluded; cyan=DAPI included.\");\n        Dialog.create(\"Review controls\");\n        Dialog.addChoice(\"Action\",newArray(\"Finish review\",\"Locate cell by ID\",\"Show cell IDs\",\"Hide cell IDs\",\"Label size and locate zoom\",\"Show all marks\",\"Hide all marks\"),\"Finish review\");\n        Dialog.show();reviewAction=Dialog.getChoice();\n        if (reviewAction==\"Finish review\") reviewActive=0;\n        else if (reviewAction==\"Show cell IDs\") {REVIEW_SHOW_IDS=1;applyReviewLabels();setReviewOutlines(1);}\n        else if (reviewAction==\"Hide cell IDs\") {REVIEW_SHOW_IDS=0;applyReviewLabels();}\n        else if (reviewAction==\"Show all marks\") setReviewOutlines(1);\n        else if (reviewAction==\"Hide all marks\") setReviewOutlines(0);\n        else if (reviewAction==\"Label size and locate zoom\") {\n            Dialog.create(\"Review appearance\");\n            Dialog.addNumber(\"ID font size (screen pixels)\",REVIEW_LABEL_SIZE);\n            Dialog.addNumber(\"Locate zoom (%)\",REVIEW_ZOOM);\n            Dialog.show();reviewFont=Dialog.getNumber();reviewMagnification=Dialog.getNumber();\n            if (isNaN(reviewFont)||reviewFont<6||reviewFont>72||isNaN(reviewMagnification)||reviewMagnification<25||reviewMagnification>3200)\n                showMessage(\"Review appearance\",\"Use font size 6-72 and locate zoom 25-3200%.\");\n            else {REVIEW_LABEL_SIZE=round(reviewFont);REVIEW_ZOOM=reviewMagnification;applyReviewLabels();}\n        } else if (reviewAction==\"Locate cell by ID\") {\n            reviewCell=getNumber(\"Cell_ID from cells.csv (1-based)\",1);\n            if (isNaN(reviewCell)||reviewCell<1||reviewCell!=floor(reviewCell)) showMessage(\"Locate cell\",\"Enter a positive integer Cell_ID.\");\n            else locateReviewCell(reviewCell);\n        }\n    }\n}\n\nfunction applyReviewLabels() {\n    for (reviewImage=0;reviewImage<previewIDs.length;reviewImage++) if (isOpen(previewIDs[reviewImage])) {\n        selectImage(previewIDs[reviewImage]);\n        if (Overlay.size>0) {\n            Overlay.useNamesAsLabels(true);Overlay.setLabelColor(\"white\");\n            // A fixed screen font remains legible without covering the cell at high zoom.\n            Overlay.setLabelFontSize(REVIEW_LABEL_SIZE,\"bold back\");\n            // setLabelFontSize enables labels: apply the requested visibility LAST.\n            Overlay.drawLabels(REVIEW_SHOW_IDS);Overlay.selectable(false);\n        }\n    }\n}\n\nfunction setReviewOutlines(visible) {\n    for (reviewImage=0;reviewImage<previewIDs.length;reviewImage++) if (isOpen(previewIDs[reviewImage])) {\n        selectImage(previewIDs[reviewImage]);\n        if (Overlay.size>0) {if (visible) Overlay.show;else Overlay.hide;}\n    }\n}\n\nfunction locateReviewCell(cellID) {\n    reviewFound=0;\n    for (reviewImage=0;reviewImage<previewIDs.length;reviewImage++) if (isOpen(previewIDs[reviewImage])) {\n        selectImage(previewIDs[reviewImage]);\n        // Every new review has exactly one ROI for each Cell_ID, including excluded nuclei.\n        if (cellID<=Overlay.size) {\n            Overlay.activateSelection(cellID-1);\n            if (Roi.getName==d2s(cellID,0)) {\n                getSelectionBounds(reviewX,reviewY,reviewW,reviewH);run(\"Select None\");\n                Overlay.show;\n                run(\"Set... \",\"zoom=\"+REVIEW_ZOOM+\" x=\"+(reviewX+reviewW/2)+\" y=\"+(reviewY+reviewH/2));\n                // A separate rectangle highlights the location without editing an overlay ROI.\n                reviewLeft=maxOf(0,reviewX-2);reviewTop=maxOf(0,reviewY-2);\n                makeRectangle(reviewLeft,reviewTop,minOf(getWidth()-reviewLeft,reviewW+4),minOf(getHeight()-reviewTop,reviewH+4));\n                reviewFound++;\n            } else run(\"Select None\");\n        }\n    }\n    if (reviewFound==0) showMessage(\"Locate cell\",\"Cell_ID not found in the open review images. Check cells.csv for this field.\");\n}\n\nfunction closePreviews() {\n    for (reviewImage=0;reviewImage<previewIDs.length;reviewImage++) if (isOpen(previewIDs[reviewImage])) {\n        selectImage(previewIDs[reviewImage]);\n        // These windows are disposable review copies; TIFFs already retain the saved overlays.\n        setOption(\"Changes\",false);close();\n    }\n    previewIDs=newArray(0);\n}\n";


var markers,channels,thresholds,minAreas,minFractions,calibrated,needed,M=0;
var nucMin,nucMax,radius,excludeEdges,dapiMethod,confirmed=0,validation="UNCONFIRMED_PREVIEW";
var inputDir="",outputBase="",runRoot="",groupDir="",configPath="",currentGroup="",comboSpec="";
var files,samples=newArray(0),fields=newArray(0),groups=newArray(0),combos,comboNames,comboRequirements,comboCount=0;
var owned=newArray(0),grayIDs,nucMask,nucLabels,regionMask,width,height,numNuclei,validCount,excludedCount,groupStatus;
var nucleusArea,ringArea,included,reasons,seedsX,seedsY,nucIndices,cellIndices,ringIndices,measurements,positives,classFlags,targetCounts;
var saved=0,oldEDM=0,roiBackup="",oldResults="",newResults="";
var dapiSegMode="GrayPeakWatershed",dapiSigma=0.8,dapiProminence=5,dapiSegGray=0,dapiOrphanPixels=0,dapiPeakX=newArray(0),dapiPeakY=newArray(0);

// ---------- Batch workflow ----------
configPath=File.openDialog("Select this project's calibration_confirmed.txt");if (configPath=="") exit();loadCalibration(configPath);
if (confirmed!=1) fail("Run the calibration macro and confirm its preview before batching.");
comboSpec=COMBINATIONS;parseCombinations();
for (m=0;m<M;m++) if (needed[m] && calibrated[m]!=1) fail("Marker is not calibrated: "+markers[m]);
inputDir=getDirectory("home");inputDir=inputDir+"Desktop/";outputBase=inputDir+"IF_results/";
Dialog.create("Simple DAPI Batch");Dialog.addDirectory("Input folder",inputDir);Dialog.addDirectory("Output folder",outputBase);
Dialog.addMessage("DAPI segmentation: "+dapiSegMode+"\nCombinations: "+COMBINATIONS+"\nThe same calibration is applied to every field.");Dialog.show();
inputDir=Dialog.getString();outputBase=Dialog.getString();inputDir=folder(inputDir);outputBase=folder(outputBase);
discoverGroups();checkFiles();validateParameters();checkRedirect();makeRun("IF_batch_");File.saveString(REVIEW_TOOLS_SOURCE,runRoot+"IF_review_saved.ijm");
validation="USER_CALIBRATED_REVIEW_REQUIRED";File.saveString(parameterText(),runRoot+"parameters_used.txt");initTables(runRoot);
beginSession();for (g=0;g<groups.length;g++) {showProgress(g,groups.length);processGroup(g,runRoot);closeOwned();}endSession();
showProgress(1);print("DONE: "+runRoot);showMessage("Batch Completed",runRoot+"positive_counts.csv\nOne row per field. Cell details are in cells.csv.\nReview images: reviews/<field>/.\nRun IF_review_saved.ijm in this run folder to reopen a field and locate Cell_IDs.");

// ---------- Read the file produced by this project's calibration ----------
function valueOf(text,key) {
    lines=split(text,"\n");for (j=0;j<lines.length;j++) {line=replace(lines[j],"\r","");prefix=key+"=";if (startsWith(line,prefix)) return substring(line,lengthOf(prefix));}
    fail("Missing parameter: "+key);return "";
}
function loadCalibration(path) {
    if (!File.exists(path)) fail("Calibration file not found: "+path);
    text=File.openAsString(path);format=valueOf(text,"format");if (format!="DAPI_CELL_V2" && format!="DAPI_CELL_V3") fail("Select a V2 or V3 calibration_confirmed.txt produced by the calibration macro.");
    mapping=valueOf(text,"mapping");pairs=split(mapping,";");M=pairs.length-1;allocateMarkers();
    first=split(pairs[0],":");if (first.length!=2 || first[1]!="DAPI") fail("The first mapping entry must identify DAPI.");channels[0]=toLowerCase(first[0]);
    for (m=0;m<M;m++) {
        pair=split(pairs[m+1],":");if (pair.length!=2) fail("Invalid marker mapping.");channels[m+1]=toLowerCase(pair[0]);markers[m]=pair[1];
        key=markers[m]+"_threshold";thresholds[m]=parseFloat(valueOf(text,key));key=markers[m]+"_min_area";minAreas[m]=parseFloat(valueOf(text,key));
        key=markers[m]+"_min_fraction";minFractions[m]=parseFloat(valueOf(text,key));key="calibrated_"+markers[m];calibrated[m]=parseFloat(valueOf(text,key));
    }
    confirmed=parseFloat(valueOf(text,"confirmed"));dapiMethod=valueOf(text,"dapi_method");
    if (format=="DAPI_CELL_V3") {
        dapiSegMode=valueOf(text,"dapi_segmentation");
        dapiSigma=parseFloat(valueOf(text,"dapi_smoothing_sigma"));dapiProminence=parseFloat(valueOf(text,"dapi_peak_prominence"));
    } else {
        // Never reinterpret an old calibration as a new segmentation algorithm.
        dapiSegMode="BinaryWatershedLegacy";dapiSigma=0;dapiProminence=5;
        print("V2 calibration: using original binary watershed. Run new calibration to enable GrayPeakWatershed.");
    }
    nucMin=parseFloat(valueOf(text,"nucleus_min"));nucMax=parseFloat(valueOf(text,"nucleus_max"));radius=parseFloat(valueOf(text,"radius"));excludeEdges=parseFloat(valueOf(text,"exclude_edges"));
}

// ---------- Marker configuration and calibration parameters ----------
function allocateMarkers() {
    markers=newArray(M);channels=newArray(M+1);thresholds=newArray(M);minAreas=newArray(M);minFractions=newArray(M);calibrated=newArray(M);
}
function mappingText() {
    s=channels[0]+":DAPI";for (m=0;m<M;m++) s=s+";"+channels[m+1]+":"+markers[m];return s;
}
function parameterText() {
    s="format=DAPI_CELL_V3\nconfirmed="+confirmed+"\nvalidation="+validation+"\nmapping=";map=mappingText();s=s+map+"\ncombinations="+comboSpec+"\n";
    s=s+"dapi_method="+dapiMethod+"\nnucleus_min="+nucMin+"\nnucleus_max="+nucMax+"\nradius="+radius+"\nexclude_edges="+excludeEdges+"\n";
    for (m=0;m<M;m++) s=s+markers[m]+"_threshold="+thresholds[m]+"\n"+markers[m]+"_min_area="+minAreas[m]+"\n"+markers[m]+"_min_fraction="+minFractions[m]+"\ncalibrated_"+markers[m]+"="+calibrated[m]+"\n";
    dapiPolicy="not_applied";if (dapiSegMode=="GrayPeakWatershed") dapiPolicy="discard_unseeded_8_connected_pieces";
    s=s+"dapi_segmentation="+dapiSegMode+"\ndapi_smoothing_sigma="+dapiSigma+"\ndapi_peak_prominence="+dapiProminence+"\ndapi_fragment_policy="+dapiPolicy+"\nimagej_version="+getVersion()+"\n";
    s=s+"units=pixel,pixel^2\nrgb_conversion=unweighted_mean\ninput_folder="+inputDir+"\n";
    if (configPath!="") s=s+"source_calibration="+configPath+"\n";
    return s;
}
function validateParameters() {
    if (M<1) fail("Configure at least one marker.");
    if (dapiSegMode!="GrayPeakWatershed" && dapiSegMode!="BinaryWatershedLegacy") fail("Unknown DAPI segmentation mode.");
    if (isNaN(dapiSigma)||dapiSigma<0||dapiSigma>5||isNaN(dapiProminence)||dapiProminence<=0||dapiProminence>255) fail("DAPI sigma must be 0-5 pixels and peak prominence >0 to 255.");
    for (m=0;m<M;m++) {
        if (!matches(markers[m],"[A-Za-z][A-Za-z0-9-]*") || toUpperCase(markers[m])=="DAPI") fail("Use unique ASCII marker names, for example CD8 or PD1.");
        for (j=0;j<m;j++) if (toUpperCase(markers[m])==toUpperCase(markers[j])) fail("Duplicate marker name.");
        for (j=0;j<=m;j++) if (channels[m+1]==channels[j]) fail("Duplicate channel name.");
        if (channels[m+1]=="") fail("Channel names cannot be empty.");
        if (needed[m] && (isNaN(thresholds[m])||thresholds[m]<1||thresholds[m]>255||thresholds[m]!=floor(thresholds[m])||isNaN(minAreas[m])||minAreas[m]<=0||isNaN(minFractions[m])||minFractions[m]<=0||minFractions[m]>1)) fail("Check threshold (1-255), area (>0) and percent (>0 to 100) for "+markers[m]);
    }
    if (channels[0]=="" || isNaN(nucMin)||isNaN(nucMax)||nucMin<=0||nucMax<nucMin||isNaN(radius)||radius<=0||radius>100||(excludeEdges!=0 && excludeEdges!=1)) fail("Check DAPI channel, nucleus areas, radius and edge setting.");
    methods=getList("threshold.methods");found=0;for (j=0;j<methods.length;j++) if (methods[j]==dapiMethod) found=1;if (!found) fail("Unknown DAPI threshold method.");
}

// ---------- Positive AND targets; all sizes are derived from M ----------
function parseCombinations() {
    weights=newArray(M);limit=1;for (m=0;m<M;m++) {weights[m]=limit;limit=limit*2;}
    if (toUpperCase(comboSpec)=="ALL") {
        comboSpec="";
        for (size=1;size<=M;size++) for (code=1;code<limit;code++) {
            count=0;item="";for (m=0;m<M;m++) if (floor(code/weights[m])%2) {count++;if (item!="") item=item+"+";item=item+markers[m];}
            if (count==size) {if (comboSpec!="") comboSpec=comboSpec+";";comboSpec=comboSpec+item;}
        }
    }
    spec=replace(comboSpec," ","");if (spec==""||startsWith(spec,";")||endsWith(spec,";")||indexOf(spec,";;")>=0) fail("Enter ALL or semicolon-separated positive combinations.");
    raw=split(spec,";");combos=newArray(0);comboNames=newArray(0);comboRequirements=newArray(0);needed=newArray(M);codes=newArray(0);
    for (k=0;k<raw.length;k++) {
        if (startsWith(raw[k],"+")||endsWith(raw[k],"+")||indexOf(raw[k],"++")>=0) fail("Invalid combination: "+raw[k]);
        parts=split(raw[k],"+");req=newArray(M);code=0;
        for (p=0;p<parts.length;p++) {
            hit=-1;for (m=0;m<M;m++) if (toUpperCase(parts[p])==toUpperCase(markers[m])) hit=m;
            if (hit<0) fail("Marker not configured: "+parts[p]);if (req[hit]) fail("Repeated marker in combination.");req[hit]=1;code=code+weights[hit];
        }
        for (j=0;j<codes.length;j++) if (codes[j]==code) fail("Duplicate combination.");
        label="";name="";for (m=0;m<M;m++) if (req[m]) {needed[m]=1;if (label!="") {label=label+"+";name=name+"_";}label=label+markers[m];name=name+markers[m];}
        combos=Array.concat(combos,newArray(label));comboNames=Array.concat(comboNames,newArray(name));comboRequirements=Array.concat(comboRequirements,req);
        one=newArray(1);one[0]=code;codes=Array.concat(codes,one);
    }
    comboCount=combos.length;comboSpec="";for (k=0;k<comboCount;k++) {if (k>0) comboSpec=comboSpec+";";comboSpec=comboSpec+combos[k];}
}
function checkFiles() {
    for (g=0;g<groups.length;g++) {findFile(g,channels[0]);for (m=0;m<M;m++) if (needed[m]) findFile(g,channels[m+1]);}
}
function makeRun(prefix) {
    File.makeDirectory(outputBase);runRoot=outputBase+prefix+d2s(getTime(),0)+"/";File.makeDirectory(runRoot);if (!File.isDirectory(runRoot)) fail("Cannot create result folder.");
}
function checkRedirect() {if (call("ij.plugin.filter.Analyzer.isRedirectImage")=="true") fail("Set Analyze > Set Measurements > Redirect to: None.");}

// ---------- TIFF pairing: sample-channel-field.tif or .tiff ----------
function folder(p) {p=replace(p,"\\","/"); if (!endsWith(p,"/")) p=p+"/"; return p;}

function stem(f) {
    l=toLowerCase(f);
    if (endsWith(l,".tiff")) return substring(f,0,lengthOf(f)-5);
    if (endsWith(l,".tif")) return substring(f,0,lengthOf(f)-4);
    return "";
}

function discoverGroups() {
    if (!File.isDirectory(inputDir)) fail("Input folder not found.");
    files=getFileList(inputDir); Array.sort(files);
    for (f=0;f<files.length;f++) {
        if (File.isDirectory(inputDir+files[f])) continue;
        s=stem(files[f]); if (s=="") continue;
        for (c=0;c<channels.length;c++) {
            token="-"+channels[c]+"-"; p=lastIndexOf(toLowerCase(s),token);
            if (p<1) continue;
            a=substring(s,0,p); b=substring(s,p+lengthOf(token)); if (b=="") continue;
            key=a+"-"+b; exists=0;
            for (j=0;j<groups.length;j++) if (toLowerCase(key)==toLowerCase(groups[j])) exists=1;
            if (!exists) {samples=Array.concat(samples,newArray(a)); fields=Array.concat(fields,newArray(b)); groups=Array.concat(groups,newArray(key));}
            break;
        }
    }
    if (groups.length==0) fail("No matching channel TIFF files were found.");
}

function findFile(g,channel) {
    expected=toLowerCase(samples[g]+"-"+channel+"-"+fields[g]); found="";
    for (i=0;i<files.length;i++) if (toLowerCase(stem(files[i]))==expected) {
        if (found!="") fail("Duplicate channel files: "+found+" / "+files[i]); found=files[i];
    }
    if (found=="") fail("Missing channel: "+expected+".tif"); return found;
}

// ---------- Preserve existing images, ROI Manager, Results and settings ----------
function beginSession() {
    roiBackup=""; oldResults=""; newResults="";
    // Temporarily detach existing Results, which Particle Analyzer may reset.
    if (nResults>0) {
        updateResults(); saveAs("Results",runRoot+"Results_before_run.csv");
        oldResults="Results_before_DAPI_"+d2s(getTime(),0); newResults="DAPI_internal_"+d2s(getTime(),0);
        Table.rename("Results",oldResults);
    }
    saveSettings(); saved=1; oldEDM=parseFloat(call("ij.plugin.filter.EDM.getOutputType"));
    setBatchMode(true); prepareSettings();
    if (roiManager("count")>0) {roiBackup=runRoot+"ROI_Manager_before_run.zip"; roiManager("Save",roiBackup);}
}

function prepareSettings() {
    setOption("BlackBackground",true); setOption("ScaleConversions",true); setRGBWeights(1/3,1/3,1/3);
    setBackgroundColor(0,0,0);
    call("ij.plugin.filter.Analyzer.setMeasurements",1); // Used for segmentation only; final cell counts do not depend on Results rows.
    call("ij.plugin.filter.EDM.setOutputType",3); // Use float EDM to avoid distances rounded by an 8-bit distance map.
}

function endSession() {
    closeOwned(); roiManager("Reset");
    if (saved) {restoreSettings(); call("ij.plugin.filter.EDM.setOutputType",oldEDM); saved=0;}
    if (oldResults!="") {if (isOpen("Results")) Table.rename("Results",newResults); Table.rename(oldResults,"Results");}
    setBatchMode(false);
    // Leaving batch mode destroys its hidden ROI Manager; restore user ROIs afterward.
    if (roiBackup!="") roiManager("Open",roiBackup);
}

function remember(id) {one=newArray(1); one[0]=id; owned=Array.concat(owned,one); return id;}

function closeOwned() {for (i=owned.length-1;i>=0;i--) if (isOpen(owned[i])) {selectImage(owned[i]); close();} owned=newArray(0);}

function duplicate(id,name) {selectImage(id); run("Select None"); resetThreshold(); run("Duplicate...","title="+name); return remember(getImageID());}

function blank(name,type) {newImage(name,type,width,height,1); return remember(getImageID());}

function q(s) {return "\""+replace(s,"\"","\"\"")+"\"";}

function cellName(i) {s=d2s(i+1,0); while (lengthOf(s)<4) s="0"+s; return "Cell_"+s;}

function fillROI(id,index,value) {selectImage(id); roiManager("Select",index); setColor(value); run("Fill"); run("Select None");}

function exactCellROI(mask,sx,sy,name) {
    selectImage(mask); run("Select None"); doWand(sx,sy,0,"4-connected");
    if (selectionType()==-1) return -1;
    getSelectionBounds(bx,by,bw,bh); getSelectionCoordinates(px,py);
    // Wand traces only the outer boundary and can swallow zero-valued interior holes.
    // Recreate an exact ROI from cropped pixels to respect distance and Voronoi limits.
    run("Duplicate...","title=DAPI_exact_roi_crop"); crop=remember(getImageID());
    for (p=0;p<px.length;p++) {px[p]=px[p]-bx; py[p]=py[p]-by;}
    makeSelection("polygon",px,py); run("Clear Outside"); run("Select None");
    setThreshold(255,255); run("Create Selection");
    if (selectionType()==-1) {close(); return -1;}
    getSelectionBounds(cx,cy,cw,ch); roiManager("Add"); idx=roiManager("count")-1;
    selectImage(mask); roiManager("Select",idx); Roi.move(bx+cx,by+cy); roiManager("Update"); roiManager("Rename",name);
    selectImage(crop); close(); selectImage(mask); roiManager("Select",idx); return idx;
}

// ==================== Field segmentation and approximate cell regions ====================

function fail(message) {if (saved) endSession();exit(message);}

function openGray(g,c) {
    open(inputDir+findFile(g,channels[c]));id=remember(getImageID());getDimensions(w,h,nc,nz,nt);depth=bitDepth;
    if (nc!=1||nz!=1||nt!=1||(depth!=8 && depth!=24)) fail("Use RGB or 8-bit single-plane TIFF: "+getTitle());
    rename("IF_work_"+g+"_"+c+"_"+d2s(getTime(),0));run("Select None");resetThreshold();run("8-bit");run("Grays");setVoxelSize(1,1,1,"pixel");return id;
}

// ---------- DAPI segmentation and nucleus-free perinuclear measurement ----------
function processGroup(g,root) {
    currentGroup=groups[g]; groupDir=root;
    print("Processing "+currentGroup+" ["+validation+"]");
    roiManager("Reset"); run("Clear Results");
    grayIDs=newArray(M+1);
    for (c=0;c<M+1;c++) if (c==0 || needed[maxOf(0,c-1)]) {
        grayIDs[c]=openGray(g,c); getDimensions(w,h,nc,nz,nt);
        if (c==0) {width=w; height=h;} else if (w!=width||h!=height) fail("Image dimensions differ within field: "+currentGroup);

    }
    // Work only on a copy; marker and original DAPI intensities are never filtered.
    dapiSegGray=0;dapiOrphanPixels=0;dapiPeakX=newArray(0);dapiPeakY=newArray(0);
    seg=duplicate(grayIDs[0],"dapi_segmentation");getRawStatistics(np,mn,mi,ma);
    uniformPositive=(mi==ma && ma>0);
    if (ma>0 && !uniformPositive) {
        if (dapiSegMode=="GrayPeakWatershed" && dapiSigma>0) run("Gaussian Blur...","sigma="+dapiSigma);
        // An 8-bit blur may turn a very low-contrast image into a constant image.
        getRawStatistics(np,mn,mi,ma);uniformPositive=(mi==ma && ma>0);
        if (ma>0 && !uniformPositive) {
            setAutoThreshold(dapiMethod+" dark");getThreshold(dapiLow,dapiHigh);
            if (dapiSegMode=="GrayPeakWatershed") {
                dapiSegGray=seg;
                // Use the same gray input/threshold/prominence for points and segmentation.
                // Explicit visible threshold avoids MaximumFinder resetting a single-value threshold.
                setThreshold(dapiLow,dapiHigh,"red");
                run("Find Maxima...","prominence="+dapiProminence+" output=[Point Selection] above");
                if (selectionType()==10) getSelectionCoordinates(dapiPeakX,dapiPeakY);
                run("Select None");setThreshold(dapiLow,dapiHigh,"red");
                // Do not exclude edge maxima: they must still seed the downstream Voronoi partition.
                run("Find Maxima...","prominence="+dapiProminence+" output=[Segmented Particles] above");
                peakOutput=getImageID();
                if (peakOutput==dapiSegGray || bitDepth!=8) fail("DAPI gray-peak segmentation did not create an 8-bit mask: "+currentGroup);
                seg=remember(peakOutput);run("Select None");resetThreshold();
                getHistogram(segValues,segHist,256);segInvalid=0;
                for (segBin=1;segBin<255;segBin++) segInvalid=segInvalid+segHist[segBin];
                if (segInvalid>0) fail("DAPI gray-peak output is not a binary mask: "+currentGroup);
                // Threshold clipping can leave detached islands in a watershed basin.
                // Keep only 8-connected pieces reached from a detected nuclear peak.
                selectImage(seg);run("Select None");setColor(254);
                for (segPeak=0;segPeak<dapiPeakX.length;segPeak++)
                    if (getPixel(dapiPeakX[segPeak],dapiPeakY[segPeak])==255) floodFill(dapiPeakX[segPeak],dapiPeakY[segPeak],"8-connected");
                getHistogram(segValues,segHist,256);dapiOrphanPixels=segHist[255];
                setThreshold(254,254,"red");run("Convert to Mask");resetThreshold();
                // Do NOT Fill Holes or run binary Watershed after this gray-guided split.
            } else {
                // Exact legacy path, retained for old V2 calibration files and comparisons.
                run("Convert to Mask");run("Fill Holes");run("Watershed");
            }
        } else {run("Select All");setColor(0);run("Fill");run("Select None");dapiLow=-1;dapiHigh=-1;}
    } else {run("Select All");setColor(0);run("Fill");run("Select None");dapiLow=-1;dapiHigh=-1;}
    run("Grays");
    // Keep edge nuclei as Voronoi seeds; apply edge exclusions after building regions.
    selectImage(seg); getHistogram(v,hist,256);
    // All segmented nuclei seed boundaries, including size rejects, to protect neighbors.
    if (hist[255]>0) {setThreshold(255,255); run("Analyze Particles...","size=0-Infinity circularity=0-1 show=Nothing add pixel");}
    numNuclei=roiManager("count");
    if (numNuclei>65534) fail("Too many nuclei for 16-bit labels; split the image into smaller fields.");
    nucMask=blank("filtered_nuclei","8-bit black"); nucLabels=blank("nuclei_IDs","16-bit black");
    nucleusArea=newArray(numNuclei); ringArea=newArray(numNuclei); included=newArray(numNuclei); reasons=newArray(numNuclei);
    seedsX=newArray(numNuclei); seedsY=newArray(numNuclei); nucIndices=newArray(numNuclei); cellIndices=newArray(numNuclei); ringIndices=newArray(numNuclei);
    measurements=newArray(numNuclei*M*3); positives=newArray(numNuclei*M);
    classFlags=newArray(numNuclei*comboCount);targetCounts=newArray(comboCount);
    validCount=0;excludedCount=0;
    for (i=0;i<numNuclei;i++) {
        nucIndices[i]=i; cellIndices[i]=-1; ringIndices[i]=-1; reasons[i]="";
        selectImage(seg); roiManager("Select",i); roiName=cellName(i); roiName=roiName+"_Nucleus"; roiManager("Rename",roiName);
        getRawStatistics(nn,mean,mn,mx); nucleusArea[i]=nn;
        fillROI(nucMask,i,255); fillROI(nucLabels,i,i+1);
    }
    if (numNuclei>0) {
        // Finite expansion: EDM on inverted nuclei measures distance to the nearest nucleus.
        inv=duplicate(nucMask,"outside_distance_input"); run("Invert"); run("Distance Map"); dist=remember(getImageID());
        setThreshold(0,radius); run("Convert to Mask"); run("Grays");
        // Voronoi interiors are zero; use 4-connected regions to prevent diagonal leakage.
        voroInput=duplicate(nucMask,"voronoi_input"); run("Voronoi"); voro=remember(getImageID());
        setThreshold(0,0); run("Convert to Mask"); run("Grays");
        selectImage(dist); da=getTitle(); selectImage(voro); vb=getTitle(); imageCalculator("AND create",da,vb); regionMask=remember(getImageID());
        run("Grays");
        for (i=0;i<numNuclei;i++) analyzeCell(i);
    }
    excludedCount=numNuclei-validCount;
    groupStatus="OK";
    if (numNuclei==0) groupStatus="NO_SEGMENTED_NUCLEI";
    if (validCount==0 && numNuclei>0) groupStatus="NO_VALID_CELL_REGIONS";
    if (uniformPositive) groupStatus="UNSEGMENTABLE_UNIFORM_DAPI";
    exportCells(root);
    row=q(currentGroup);row=row+","+numNuclei+","+validCount+","+excludedCount;
    for (k=0;k<comboCount;k++) {row=row+",";if (validCount>0) row=row+targetCounts[k];}
    File.append(row+","+groupStatus+","+validation+","+dapiLow+","+dapiHigh,root+"positive_counts.csv");
    if (SAVE_REVIEW_IMAGES) {
        File.makeDirectory(root+"reviews/");reviewFieldDir=root+"reviews/"+currentGroup+"/";saveReviewBundle(reviewFieldDir,seg,0);
    }
}

function analyzeCell(i) {
    id=i+1; text=cellName(i);
    selectImage(nucLabels); roiManager("Select",nucIndices[i]); getSelectionBounds(nx,ny,nw,nh);
    // A centroid can lie outside a concave nucleus; scan for a genuine inside pixel.
    sx=-1; sy=-1;
    for (y=ny;y<ny+nh && sx<0;y++) for (x=nx;x<nx+nw && sx<0;x++) if (getPixel(x,y)==id) {sx=x; sy=y;}
    seedsX[i]=sx; seedsY[i]=sy;
    if (sx<0) {reasons[i]="NO_NUCLEAR_SEED"; return;}
    selectImage(regionMask); run("Select None");
    if (getPixel(sx,sy)!=255) {reasons[i]="SEED_ON_PARTITION_BOUNDARY"; return;}
    cellTitle=text+"_Cell"; ci=exactCellROI(regionMask,sx,sy,cellTitle);
    if (ci<0) {reasons[i]="NO_CELL_REGION"; return;}
    cellIndices[i]=ci;
    getSelectionBounds(rx,ry,rw,rh);
    // Require exactly the complete own nucleus and no foreign nuclei in each region.
    selectImage(nucLabels); roiManager("Select",ci); ownPixels=0; foreign=0;
    for (y=ry;y<ry+rh;y++) for (x=rx;x<rx+rw;x++) if (selectionContains(x,y)) {
        label=getPixel(x,y); if (label==id) ownPixels++; else if (label>0) foreign=1;
    }
    if (foreign) {reasons[i]="MULTIPLE_NUCLEI_IN_REGION"; return;}
    if (ownPixels!=nucleusArea[i]) {reasons[i]="NUCLEUS_TRUNCATED_BY_REGION"; return;}
    // XOR with the own nucleus gives the nucleus-free perinuclear region.
    selectImage(regionMask); roiManager("Select",newArray(nucIndices[i],ci)); roiManager("XOR");
    if (selectionType()==-1) {reasons[i]="EMPTY_RING"; return;}
    getRawStatistics(nn,mean,mn,mx); ringArea[i]=nn;
    if (nn<=0) {reasons[i]="EMPTY_RING"; return;}
    roiManager("Add"); ri=roiManager("count")-1; ringIndices[i]=ri; roiManager("Select",ri); roiManager("Rename",text+"_Ring");
    edge=(nx==0||ny==0||nx+nw>=width||ny+nh>=height||rx==0||ry==0||rx+rw>=width||ry+rh>=height);
    if (nucleusArea[i]<nucMin || nucleusArea[i]>nucMax) reasons[i]="NUCLEAR_AREA";
    else if (excludeEdges && edge) reasons[i]="IMAGE_EDGE";
    else {included[i]=1; validCount++;}
    // Measure original gray means and threshold-positive area; denominator is full valid ring area.
    for (m=0;m<M;m++) if (needed[m]) {
        selectImage(grayIDs[m+1]); roiManager("Select",ri); resetThreshold(); getHistogram(v,hist,256);
        n=0; weighted=0; positiveArea=0;
        for (b=0;b<256;b++) {n=n+hist[b]; weighted=weighted+b*hist[b]; if (b>=thresholds[m]) positiveArea=positiveArea+hist[b];}
        if (n!=ringArea[i]) fail("Internal error: inconsistent perinuclear area: "+currentGroup+" "+text);
        avg=weighted/n; fraction=positiveArea/n;
        offset=(i*M+m)*3; measurements[offset]=avg; measurements[offset+1]=positiveArea; measurements[offset+2]=fraction;
        positives[i*M+m]=(positiveArea>=minAreas[m] && fraction>=minFractions[m]);
    }
    // A target is positive only for an included cell positive for every required marker.
    for (k=0;k<comboCount;k++) {
        hit=included[i];for (m=0;m<M;m++) if (comboRequirements[k*M+m] && !positives[i*M+m]) hit=0;
        classFlags[i*comboCount+k]=hit;targetCounts[k]=targetCounts[k]+hit;
    }
}

// ---------- One summary table and one cell table; invalid fields have blank counts ----------
function initTables(root) {
    header="Group,Total_segmented_nuclei,Valid_cells,Excluded_cells";for (k=0;k<comboCount;k++) header=header+","+comboNames[k];
    File.saveString(header+",Status,Validation,DAPI_threshold_low,DAPI_threshold_high\n",root+"positive_counts.csv");
    header="Group,Cell_ID,Seed_X_px,Seed_Y_px,Nucleus_area_px2,Ring_area_px2,Included,Exclusion_reason";
    for (m=0;m<M;m++) if (needed[m]) header=header+","+markers[m]+"_mean,"+markers[m]+"_positive_area_px2,"+markers[m]+"_positive_fraction,"+markers[m]+"_marker_positive";
    for (k=0;k<comboCount;k++) header=header+","+comboNames[k]+"_positive";File.saveString(header+"\n",root+"cells.csv");
}
function exportCells(root) {
    s="";for (i=0;i<numNuclei;i++) {
        row=q(currentGroup);row=row+","+(i+1)+","+seedsX[i]+","+seedsY[i]+","+nucleusArea[i]+","+ringArea[i]+","+included[i]+","+q(reasons[i]);
        for (m=0;m<M;m++) if (needed[m]) {z=(i*M+m)*3;if (ringIndices[i]>=0) row=row+","+d2s(measurements[z],6)+","+measurements[z+1]+","+d2s(measurements[z+2],8)+","+positives[i*M+m];else row=row+",,,,";}
        for (k=0;k<comboCount;k++) row=row+","+classFlags[i*comboCount+k];s=s+row+"\n";
    }
    if (s!="") File.append(s,root+"cells.csv");
}

// Reviews are separate 8-bit copies plus editable vector overlays. No pixels are drawn.
function saveImage(id,name) {
    selectImage(id);run("Select None");resetThreshold();saveAs("Tiff",groupDir+name+".tif");
}

function saveReviewBundle(root,seg,saveMasks) {
    reviewPreviousDir=groupDir;groupDir=root;File.makeDirectory(groupDir);
    saveImage(nucLabels,"nuclei_labels");
    saveDapiDiagnostics(seg);
    // Archive the original geometry and names before building display-only ROI clones.
    if (roiManager("count")>0) roiManager("Save",groupDir+"all_regions.zip");
    else File.saveString("No segmented nuclei; no ROIs were created.\n",groupDir+"NO_ROIS.txt");
    reviewIndex="Cell_ID,Nucleus_ROI_name,Cell_ROI_name,Ring_ROI_name,Included,Exclusion_reason\n";
    for (rvCell=0;rvCell<numNuclei;rvCell++) {
        rvCellName="";rvRingName="";rvNameBase=cellName(rvCell);
        if (cellIndices[rvCell]>=0) rvCellName=rvNameBase+"_Cell";
        if (ringIndices[rvCell]>=0) rvRingName=rvNameBase+"_Ring";
        reviewIndex=reviewIndex+(rvCell+1)+","+rvNameBase+"_Nucleus,"+rvCellName+","+rvRingName+","+included[rvCell]+","+reasons[rvCell]+"\n";
    }
    File.saveString(reviewIndex,groupDir+"review_roi_index.csv");
    rvView=makeReview(grayIDs[0],"DAPI_review");
    for (rvCell=0;rvCell<numNuclei;rvCell++) {
        rvColor="#ff9900";if (included[rvCell]) rvColor="#00ffff";
        addReviewROI(rvView,nucIndices[rvCell],rvColor,d2s(rvCell+1,0));
    }
    finishReview(rvView,"DAPI");saveImage(rvView,"dapi_cells_review");
    for (rvMarker=0;rvMarker<M;rvMarker++) if (needed[rvMarker]) {
        if (saveMasks) {
            rvFileName=markers[rvMarker]+"_8bit";saveImage(grayIDs[rvMarker+1],rvFileName);
            rvMask=duplicate(grayIDs[rvMarker+1],"signal_mask");setThreshold(thresholds[rvMarker],255);run("Convert to Mask");run("Grays");
            rvFileName=markers[rvMarker]+"_signal_mask";saveImage(rvMask,rvFileName);
        }
        rvView=makeReview(grayIDs[rvMarker+1],"marker_review");
        for (rvCell=0;rvCell<numNuclei;rvCell++) {
            rvColor="#ff9900";
            if (included[rvCell]) {rvColor="#ff4444";if (positives[rvCell*M+rvMarker]) rvColor="#00ff00";}
            rvIndex=ringIndices[rvCell];
            // Excluded nuclei with no usable ring remain locatable, shown as orange nuclei.
            if (rvIndex<0) rvIndex=nucIndices[rvCell];
            addReviewROI(rvView,rvIndex,rvColor,d2s(rvCell+1,0));
        }
        finishReview(rvView,markers[rvMarker]);rvFileName=markers[rvMarker]+"_review";saveImage(rvView,rvFileName);
    }
    if (saveMasks) saveImage(grayIDs[0],"DAPI_8bit");
    File.saveString("Open *_review.tif in ImageJ. Contours and IDs are an overlay independent of image pixels.\nIDs are hidden by default to avoid crowding. Run IF_review_saved.ijm from the run folder for font/ID controls and Cell_ID locate.\nUse Image > Overlay > Labels for native label options. Use the magnifier or +/- to zoom.\nMarker green=positive, red=negative, orange=excluded; DAPI cyan=included.\nEach overlay position i corresponds to Cell_ID i+1, not an all_regions.zip ROI Manager row.\nWhen a ring is missing, its excluded nucleus is shown in orange.\nThe gray pixel data are unchanged; brightness stretching is display-only. Review edits do not recalculate counts.\n",groupDir+"HOW_TO_REVIEW.txt");
    groupDir=reviewPreviousDir;
}

function makeReview(id,name) {
    rvCopy=duplicate(id,name);Overlay.remove;
    getRawStatistics(rvPixels,rvMean,rvMin,rvMax);setMinAndMax(0,maxOf(1,rvMax));
    // Keep 8-bit pixel values unchanged. Do NOT RGB-convert, Draw, drawString or Flatten.
    return rvCopy;
}

function addReviewROI(id,index,color,label) {
    selectImage(id);roiManager("Select",index);
    // Clone even if the ROI Manager's Show All mode uses the original ROI object.
    Roi.copy;Roi.paste;Roi.setName(label);
    Overlay.addSelection(color,0);run("Select None");
}

function finishReview(id,marker) {
    selectImage(id);run("Select None");
    if (Overlay.size>0) {
        Overlay.useNamesAsLabels(true);Overlay.setLabelColor("white");
        Overlay.setLabelFontSize(REVIEW_LABEL_SIZE,"bold back");
        Overlay.drawLabels(REVIEW_SHOW_IDS);Overlay.selectable(false);
        // ImageJ omits hidden overlays from TIFF: keep OUTLINES visible when saving.
        Overlay.show;
    }
    setMetadata("Info","IF review overlay v1\nField="+currentGroup+"\nMarker="+marker+"\nCell_ID=overlay name (1-based), identical to cells.csv\nGreen=positive; red=negative; orange=excluded; cyan=DAPI included\nPixel values are unchanged; display range may be stretched.\nDAPI_segmentation="+dapiSegMode+"; sigma="+dapiSigma+"; prominence="+dapiProminence+"\n");
}

function showPreview(dir) {
    previewIDs=newArray(0);rvPath=dir+"dapi_cells_review.tif";openReviewFile(rvPath);
    for (rvMarker=0;rvMarker<M;rvMarker++) if (needed[rvMarker]) {
        rvPath=dir+markers[rvMarker]+"_review.tif";openReviewFile(rvPath);
    }
    applyReviewLabels();
}

function openReviewFile(path) {
    if (!File.exists(path)) return;
    open(path);rvOne=newArray(1);rvOne[0]=getImageID();previewIDs=Array.concat(previewIDs,rvOne);
}

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

// Additional diagnostic outputs; never change nucleus geometry, inclusion, or marker measurements.
function saveDapiDiagnostics(seg) {
    selectImage(seg);Overlay.remove;saveImage(seg,"dapi_segmented_mask");
    if (dapiSegGray!=0 && isOpen(dapiSegGray)) {selectImage(dapiSegGray);Overlay.remove;saveImage(dapiSegGray,"dapi_smoothed_input");}
    diagCounts=newArray(numNuclei);diagUnassigned=0;
    diagText="Peak_index,Peak_X_px,Peak_Y_px,Cell_ID\n";
    for (diagPeak=0;diagPeak<dapiPeakX.length;diagPeak++) {
        selectImage(nucLabels);run("Select None");diagLabel=getPixel(dapiPeakX[diagPeak],dapiPeakY[diagPeak]);
        if (diagLabel>0 && diagLabel<=numNuclei) {diagIndex=diagLabel-1;diagCounts[diagIndex]=diagCounts[diagIndex]+1;}
        else {diagLabel=0;diagUnassigned++;}
        diagText=diagText+(diagPeak+1)+","+dapiPeakX[diagPeak]+","+dapiPeakY[diagPeak]+","+diagLabel+"\n";
    }
    File.saveString(diagText,groupDir+"dapi_peaks.csv");
    diagZero=0;diagMultiple=0;diagValidZero=0;diagValidMultiple=0;
    if (dapiSegMode=="GrayPeakWatershed") for (diagCell=0;diagCell<numNuclei;diagCell++) {
        if (diagCounts[diagCell]==0) {diagZero++;if (included[diagCell]) diagValidZero++;}
        if (diagCounts[diagCell]>1) {diagMultiple++;if (included[diagCell]) diagValidMultiple++;}
    }
    diagInfo="dapi_segmentation="+dapiSegMode+"\ndapi_smoothing_sigma="+dapiSigma+"\ndapi_peak_prominence="+dapiProminence;
    diagInfo=diagInfo+"\nremoved_unseeded_pixels="+dapiOrphanPixels+"\nsegmented_nuclei="+numNuclei+"\npeak_points="+dapiPeakX.length+"\nunassigned_peaks="+diagUnassigned+"\nnuclei_without_peak="+diagZero+"\nnuclei_with_multiple_peaks="+diagMultiple+"\nvalid_nuclei_without_peak="+diagValidZero+"\nvalid_nuclei_with_multiple_peaks="+diagValidMultiple+"\n";
    diagInfo=diagInfo+"Peak mapping is a technical consistency check, not biological ground truth. Legacy mode has no gray-peak diagnostics.\n";
    File.saveString(diagInfo,groupDir+"dapi_segmentation_qc.txt");
    if (dapiPeakX.length>0) {
        diagView=makeReview(grayIDs[0],"dapi_peak_points");
        for (diagPeak=0;diagPeak<dapiPeakX.length;diagPeak++) {
            selectImage(diagView);makeOval(dapiPeakX[diagPeak]-1,dapiPeakY[diagPeak]-1,2,2);
            Overlay.addSelection("#ffff00",0);run("Select None");
        }
        Overlay.drawLabels(false);Overlay.selectable(false);Overlay.show;
        setMetadata("Info","DAPI gray-peak points. Yellow circles mark peak coordinates; see dapi_peaks.csv for Cell_ID mapping. This is not an indexed Cell_ID review image.");
        // Not named *_review.tif: the normal reviewer assumes one indexed ROI per Cell_ID.
        saveImage(diagView,"dapi_peak_points_preview");
    }
}
