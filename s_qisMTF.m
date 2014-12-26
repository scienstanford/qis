%% s_qisMTF
%
% Illustrate MTF calculation
%
%%
s_initISET

%%
scene = sceneCreate('slanted edge'); 
scene = sceneSet(scene,'fov',2);
ieAddObject(scene); 
sceneWindow;

oi = oiCreate; oi = oiCompute(oi,scene);
ieAddObject(oi); oiWindow;

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
sensor = sensorSet(sensor,'voltage swing',0.1);   % 100 mV
sensor = sensorSet(sensor,'exposure time',0.0005);  % Half millisecond exposure
sensor = sensorCompute(sensor,oi);
vcAddObject(sensor);
sensorWindow('scale',1);
% sensorGet(sensor,'pixel fill factor')

% Look at: pixelCenterFillPD

% Make the sensor size (field of view) roughly match the scene field of
% view.  I made it a little smaller because, well, it seemed like a good
% idea at the time.
sensor = sensorSetSizeToFOV(sensor,sceneGet(scene,'fov'));

%% Compute
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
vcNewGraphWin; imagesc(e)

close(w)

%% Show the image as the sum of jots

%  There should be many types of computations here. That's where the
%  creativity will come in, I think.

ip = vcimageCreate;
v = sum(jot,3);
result = repmat(v,[1 1 3]);
ip = imageSet(ip,'result',result);

% Add the object to the IP window so we can interact with it
ieAddObject(ip);
vcimageWindow;

%% Use ISO12233 routines

% These routines could all be better

% The selection of the masterRect is a bit sketchy with these very noisy
% data.  
% masterRect = [305   187   363   431]; 
masterRect = ISOFindSlantedBar(ip,true);
% We need a routine that draws the rect on the ip image

barImage = vcGetROIData(ip,masterRect,'results');
c = masterRect(3)+1;
r = masterRect(4)+1;
barImage = reshape(barImage,r,c,3);
% vcNewGraphWin; imagesc(barImage(:,:,1)); axis image; colormap(gray);

% Run the ISO 12233 code.  The results are stored in the window.
pixel = sensorGet(sensor,'pixel');
dx = pixelGet(pixel,'width','mm');
ISO12233(barImage, dx) 
set(gca,'xscale','log')

ieAddObject(ip); vcimageWindow;
h = ieDrawShape(ip,'rectangle',masterRect);

%% END