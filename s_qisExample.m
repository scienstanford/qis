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
% 
% fname = fullfile(isetRootPath,'data','images','rgb','eagle.jpg');
% scene = sceneFromFile(fname,'rgb');
% fname = fullfile(isetRootPath,'data','images','multispectral','Feng_Office-hdrs.mat');
% scene = sceneFromFile(fname,'multispectral');

% scene = sceneCreate('uniform');
% scene = sceneCreate; % default is Macbeth ColorChecker
% scene = sceneCreate('slanted edge'); 
% scene = sceneSet(scene,'fov',2);
% ieAddObject(scene);
% sceneWindow;

scene = sceneHDRChart;
scene = sceneSet(scene,'fov',2);
ieAddObject(scene);
sceneWindow;


% Many optics parameters can be set.  To get a sense, run
% doc oiCreate
% doc opticsCreate
%
oi = oiCreate;
oi = oiSet(oi,'optics fnumber', 2.8);
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

sensor = sensorCreateIdeal('monochrome');         % No sensor noise
sensor = sensorSet(sensor,'pixel size',0.14e-6);  % .14 microns
sensor = sensorSet(sensor,'pixel pd width and height',[0.14,0.14]*1e-6);
% sensorGet(sensor,'pixel fill factor')

% Look at: pixelCenterFillPD

% Make the sensor size (field of view) roughly match the scene field of
% view.  I made it a little smaller because, well, it seemed like a good
% idea at the time.
sensor = sensorSetSizeToFOV(sensor,sceneGet(scene,'fov'));

%% Look at some data

sensor = sensorSet(sensor,'exposure time',0.0005);  % Half millisecond exposure
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

%% Now loop, to make a series of snapshots

sz = sensorGet(sensor,'size');
nFrames = 16;    % For the example
jot = zeros(sz(1),sz(2),nFrames);

%  Haven't really parallelized yet.  We will some day soon.
w = waitbar(0,'QIS snapshots');
for ii=1:nFrames
    waitbar(ii/nFrames,w,sprintf('Scene %i',ii));  
    
    % There will be a sensorComputeMovie before too long.
    tmp = sensorCompute(sensor,oi);
    
    % Try doc sensorGet to see what you can pull from this object
    e = sensorGet(tmp,'electrons');
    e(e>0) = 1;         % Binarize
    jot(:,:,ii) = e;    % Store
end
close(w)

%% Show the image as the sum of jots

%  There should be many types of computations here. That's where the
%  creativity will come in, I think.
v = sum(jot,3);
vcNewGraphWin([],'tall'); 
subplot(3,1,1)
imagesc(v); axis off, axis image
colormap(gray(16))

%  Equivalent of about a 1 um pixel, but upsampled to 0.14 um spacing
g = fspecial('gaussian',[9 9],3);
vs = conv2(v,g,'same');
subplot(3,1,2)
imagesc(vs); axis off,  axis image
colormap(gray(256))

% Maybe a 2 um pixel
g = fspecial('gaussian',[18 18],6);
vs = conv2(v,g,'same');
subplot(3,1,3)
imagesc(vs); axis off,  axis image
colormap(gray(256))


%% Create image processing object

% OLD
ip = vcimageCreate;

ip = imageSet(ip,'sensor input',vs);
ip = vcimageCompute(ip,sensor);
ieAddObject(ip);
vcimageWindow;

%% Create image processing object

% Create an image processing object
ip = vcimageCreate;

% Put the voltages into the result field of the image processing module
result = repmat(vs,[1 1 3]);
ip = imageSet(ip,'result',result);

% Add the object to the IP window so we can interact with it
ieAddObject(ip);
vcimageWindow;


%% 





%% End

