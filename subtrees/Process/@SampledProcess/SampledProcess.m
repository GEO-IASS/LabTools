% Regularly sampled processes

% If multiple processes, currently cannot be multidimensional,
% time = rows

classdef(CaseInsensitiveProperties) SampledProcess < Process   
   properties(AbortSet)
      tStart             % Start time of process
      tEnd               % End time of process
   end
   properties(SetAccess = protected)
      Fs                 % Sampling frequency
   end
   properties(SetAccess = protected, Dependent = true, Transient = true)
      dt                 % 1/Fs
      dim                % Dimensionality of each window
   end   
   properties(SetAccess = protected, Hidden = true)
      Fs_                % Original sampling frequency
   end
   properties(SetAccess = protected, Hidden = true)
      times_              % Original event/sample times
      values_             % Original attribute/values
   end
   
   %%
   methods
      %% Constructor
      function self = SampledProcess(varargin)
         self = self@Process;
         if nargin == 0
           return;
         end
         
         if mod(nargin,2)==1 && ~isstruct(varargin{1})
            assert(isnumeric(varargin{1}) || isa(varargin{1},'StreamTest'),...
               'SampledProcess:Constructor:InputFormat',...
               'Single inputs must be passed in as array of numeric values');
            varargin = {'values' varargin{:}};
         end

         p = inputParser;
         p.KeepUnmatched= false;
         p.FunctionName = 'SampledProcess constructor';
         p.addParameter('info',containers.Map('KeyType','char','ValueType','any'));
         p.addParameter('Fs',1);
         p.addParameter('values',[],@(x) isnumeric(x) || isa(x,'StreamTest'));
         p.addParameter('labels',{},@(x) iscell(x) || ischar(x));
         p.addParameter('quality',[],@isnumeric);
         p.addParameter('window',[],@isnumeric);
         p.addParameter('offset',[],@isnumeric);
         p.addParameter('tStart',0,@isnumeric);
         p.addParameter('tEnd',[],@isnumeric);
         p.parse(varargin{:});
         
         self.info = p.Results.info;
         % Create values array
         if isvector(p.Results.values)
            self.values_ = {p.Results.values(:)};
         else
            self.values_ = {p.Results.values};
         end
         self.Fs_ = p.Results.Fs;
         self.Fs = self.Fs_;
         dt = 1/self.Fs_;
         dim = size(self.values_{1});
         self.times_ = {self.tvec(p.Results.tStart,dt,dim(1))};

          keyboard
        %%%% 
         self.times = self.times_;
         self.values = self.values_;

         % Define the start and end times of the process
         self.tStart = p.Results.tStart;
         
         if isempty(p.Results.tEnd)
            self.tEnd = self.times_{1}(end);
         else
            self.tEnd = p.Results.tEnd;
         end

         % Set the window
         if isempty(p.Results.window)
            self.setInclusiveWindow();
         else
            self.window = checkWindow(p.Results.window,size(p.Results.window,1));
         end
         
         % Set the offset
         self.cumulOffset = 0;
         if isempty(p.Results.offset)
            self.offset = 0;
         else
            self.offset = checkOffset(p.Results.offset,size(p.Results.offset,1));
         end         

         % Create labels
         self.labels = p.Results.labels;
         
         self.quality = p.Results.quality;

         % Store original window and offset for resetting
         self.window_ = self.window;
         self.offset_ = self.offset;
      end % constructor

%       function times_ = get.times_(self)
%          times_ = {self.tvec(self.tStart,dt,(size(self.values_{1},1)))};
%       end
      
      function set.tStart(self,tStart)
         if ~isempty(self.tEnd)
            assert(tStart < self.tEnd,'SampledProcess:tEnd:InputValue',...
                  'tStart must be less than tEnd.');
         end
         assert(isscalar(tStart) && isnumeric(tStart),...
            'SampledProcess:tStart:InputFormat',...
            'tStart must be a numeric scalar.');
         dim = size(self.values_{1});
         [pre,preV] = self.extendPre(self.tStart,tStart,1/self.Fs_,dim(2:end));
         self.times_ = {[pre ; self.times_{1}]};
         self.values_ = {[preV ; self.values_{1}]};
         self.tStart = tStart;

         self.discardBeforeStart();
         if ~isempty(self.tEnd)
            self.setInclusiveWindow();
         end
      end
      
      function set.tEnd(self,tEnd)
         if ~isempty(self.tStart)
            assert(self.tStart < tEnd,'SampledProcess:tEnd:InputValue',...
                  'tEnd must be greater than tStart.');
         end
         assert(isscalar(tEnd) && isnumeric(tEnd),...
            'SampledProcess:tEnd:InputFormat',...
            'tEnd must be a numeric scalar.');
         dim = size(self.values_{1});
         [post,postV] = self.extendPost(self.tEnd,tEnd,1/self.Fs_,dim(2:end));
         self.times_ = {[self.times_{1} ; post]};
         self.values_ = {[self.values_{1} ; postV]};
         self.tEnd = tEnd;
         
         self.discardAfterEnd();
         if ~isempty(self.tStart)
            self.setInclusiveWindow();
         end
      end
      
      function dt = get.dt(self)
         dt = 1/self.Fs;
      end
      
      function dim = get.dim(self)
         dim = cellfun(@(x) size(x),self.values,'uni',false);
      end
      
      % 
      obj = chop(self,shiftToWindow)
      s = sync(self,event,varargin)

      % Transform
      self = filter(self,b,varargin)
      [self,b] = highpass(self,corner,varargin)
      [self,b] = lowpass(self,corner,varargin)
      [self,b] = bandpass(self,corner,varargin)
      self = resample(self,newFs,varargin)
      self = detrend(self)

      % Output
      [s,labels] = extract(self,reqLabels)
      output = apply(self,fun,nOpt,varargin)

      dat = convert2Fieldtrip(self)
      
      % Visualization
      [h,yOffset] = plot(self,varargin)
   end
   
   methods(Access = protected)
      applyWindow(self)
      applyOffset(self,offset)
   end
   
   methods(Static)
      obj = loadobj(S)
      t = tvec(t0,dt,n)
      [pre,preV] = extendPre(tStartOld,tStartNew,dt,dim)
      [post,postV] = extendPost(tEndOld,tEndNew,dt,dim)
   end
end
