% s_qisExample - Draft for Rachel
%
% The purpose of this script is to illustrate 
%
%   * how to read a description of the scene radiance
%   * create an optical irradiance image, 
%   * create a sensor with QIS characteristics
%   * Obtain estimates of the jots
%
% 2014, Stanford Vistasoft Team

%% 
s_initISET

%% Read a scene and make an optical image

% There are a variety of built-in scenes.  It is also possible to read in
% an RGB image.
%
% To learn more about scenes type 'doc sceneCreate'

% RGB Images -----------------------
% fname = fullfile(isetRootPath,'data','images','rgb','eagle.jpg');
% scene = sceneFromFile(fname,'rgb');
% fname = fullfile('O:\QIS HDR\','lena512_color.png');    % illustrative purposes only
% scene = sceneFromFile(fname,'rgb');

% Multispectral Images --------------
% fname = fullfile(isetRootPath,'data','images','multispectral','Feng_Office-hdrs.mat');
% scene = sceneFromFile(fname,'multispectral');

% Test Patterns ---------------------
% scene = sceneCreate('uniform');
scene = sceneCreate; % default is Macbeth ColorChecker
% scene = sceneCreate('slanted edge'); 
scene = sceneSet(scene,'fov',2);

%scene = sceneAdjustLuminance(scene,100);  % Set to 100 cd/m2.

% HDR Gradient -----------------------
% dRange = 10^7;                            
% nLevels = 20;
% rowsPerLevel = 10;
% maxLum = 10000;
% scene = sceneHDRChart(dRange,nLevels,rowsPerLevel,maxLum);
% ieAddObject(scene); sceneWindow;
% scene = sceneSet(scene,'fov',2);

% Many optics parameters can be set.  To get a sense, run
% doc oiCreate
% doc opticsCreate
%
oi = oiCreate;
%oi = oiSet(oi,'optics fnumber', 2.8);
oi = oiCompute(oi,scene);

%% Make a QIS style sensor.

% We create a sensor with a very small pixel and very little noise.
% At some point, we could add a function such as
% 
%    qis = sensorCreate('qis');
%
% To see additional properties that could be created or set try
%
%  doc sensorCreate
%  doc pixelCreate
voltageSwing   = .1;  % Volts
wellCapacity   = 100;  % Electrons
conversiongain = voltageSwing/wellCapacity;
% rows = 4096;               % number of pixels in a row
% cols = 4096;               % number of pixels in a column
% rows = 256;
% cols = 256;
sensor = sensorCreateIdeal('monochrome');         % No sensor noise
sensor = sensorSet(sensor,'pixel size',0.14e-6);  % .14 microns
sensor = sensorSet(sensor,'pixel pd width and height',[0.14,0.14]*1e-6);
sensor = sensorSet(sensor,'pixel conversiongain', conversiongain);
sensor = sensorSet(sensor,'pixel voltageswing', voltageSwing);
% sensor = sensorSet(sensor,'size',[rows,cols]);      % for facilitating 16x16 recombination


% sensorGet(sensor,'pixel fill factor')

% Look at: pixelCenterFillPD

% Make the sensor size (field of view) roughly match the scene field of
% view.  I made it a little smaller because, well, it seemed like a good
% idea at the time.
sensor = sensorSetSizeToFOV(sensor,sceneGet(scene,'fov'));

%% Look at some data
%exptime = 10e-6;                                    % 10 us exposure
exptime = 500e-6;
sensor = sensorSet(sensor,'exposure time',exptime);  
sensor = sensorCompute(sensor,oi);
vcAddObject(sensor);
sensorWindow('scale',1);

%% Look at the electron distribution

% Snag the electrons
e = sensorGet(sensor,'electrons');
mean(e(:))

vcNewGraphWin;
% Choosing the xvalues this way forces the histogram to plot correctly,
% with no gaps.
hist(e(:),1:max(e(:)))

%% Make the (binary) jot image

% Set the electrons to zero if none, 1 if more than zero.
e(e > 0) = 1;

% Show a picture
vcNewGraphWin;
imagesc(e);
colormap([0 0 0; 1 1 1]);

%% Create Jot Cube

sz = sensorGet(sensor,'size');
nFrames = 16;    % For the example
jot = zeros(sz(1),sz(2),nFrames);

% NON-HDR
w = waitbar(0,'QIS snapshots');
parfor ii=1:nFrames
    waitbar(ii/nFrames,w,sprintf('Scene %i',ii));  
    tmp = sensorCompute(sensor,oi);
    e = sensorGet(tmp,'electrons');
    e(e>0) = 1;         % Binarize
    jot(:,:,ii) = e;    % Store
end
close(w)

% HDR
% HDRtimes = [1 1 1 1 .2 .2 .2 .2 .04 .04 .04 .04 .008 .008 .008 .008];
% w = waitbar(0,'QIS snapshots');
% parfor ii=1:nFrames
%     waitbar(ii/nFrames,w,sprintf('Scene %i',ii));    
%     tmp = sensorSet(sensor,'exposure time',exptime*HDRtimes(ii)); 
%     tmp = sensorCompute(tmp,oi);
%     e = sensorGet(tmp,'electrons');
%     e(e>0) = 1;         % Binarize
%     jot(:,:,ii) = e;    % Store
% end
% close(w)


%% Jot Recombination

%  There should be many types of computations here. That's where the
%  creativity will come in, I think.
v = sum(jot,3);
%vcNewGraphWin([],'tall'); 
figure
imshow(v,[])
title('Jots Summed in Time-Direction')
colormap(gray(16))

%  Equivalent of about a 1 um pixel, but upsampled to 0.14 um spacing
g = fspecial('gaussian',[9 9],3);
vs1 = conv2(v,g,'same');
figure
imshow(vs1,[])
title('Jots Summed Time-Direction, 9x9 Gauss')

colormap(gray(256))

% Maybe a 2 um pixel
g = fspecial('gaussian',[18 18],6);
vs2 = conv2(v,g,'same');
figure
imshow(vs2,[])
title('Jots Summed Time-Direction, 18x18 Gauss')
colormap(gray(256))

% Gaussian blur then downsample
g = fspecial('gaussian',[18 18],6);
vs3 = conv2(v,g,'same');
%figure
%imshow(vs3,[])
vs3 = imresize(vs3,1/16);
figure
imshow(vs3,[])
title('Jots Summed Time-Direction, 9x9 Gauss, DS')
colormap(gray(256))

% 16x16x16 jot to pixel recombination
% for c = 1:16:sz(2)
%     for r = 1:16:sz(1)
%         A = jot(r:r+15, c:c+15, :);             % 16x16x16 cube of jots
%         value = nnz(A)/16^3;                    % count ones in cube
%         outRow = (r-1)/16 + 1;
%         outCol = (c-1)/16 + 1;
%         vs4(outRow, outCol) = value;
%     end
% end
% %imOut = (imOut - min(imOut(:)))/(max(imOut(:)) - min(imOut(:)));
% figure
% imshow(vs4,[])
% title('16x16x16 recombination')
% colormap(gray(256))


%% Create image processing object

% Create an image processing object
ip = vcimageCreate;

% Put the voltages into the result field of the image processing module
result = repmat(v,[1 1 3]);
ip = imageSet(ip,'result',result);

% Add the object to the IP window so we can interact with it
ieAddObject(ip);
vcimageWindow;

%% MTF
% 
% %[roiLocs,masterRect] = vcROISelect(ip);
% masterRect = [305   187   363   431]; 
% 
% roiLocs = ieRoi2Locs(masterRect);
% 
% barImage = vcGetROIData(ip,roiLocs,'results');
% c = masterRect(3)+1;
% r = masterRect(4)+1;
% barImage = reshape(barImage,r,c,3);
% % vcNewGraphWin; imagesc(barImage(:,:,1)); axis image; colormap(gray);
% 
% % Run the ISO 12233 code.  The results are stored in the window.
% pixel = sensorGet(sensor,'pixel');
% dx = pixelGet(pixel,'width','mm');
% ISO12233(barImage, dx) 
% 

%% End

