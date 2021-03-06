% LOWPASS - Design and optionally apply lowpass filter to SampledProcess
%
%     [self,h,d,hft] = lowpass(SampledProcess,varargin)
%     SampledProcess.lowpass(varargin)
%
%     The default is to filter using an linear-phase even-order FIR filter,
%     designed with an equiripple design algorithm. For very stringent 
%     specifications, this may fail to converge or take too long. It may be 
%     worthwhile to switch to a window design method (see OPTIONAL and 
%     EXAMPLES below).
%
%     Data is filtered using a single-pass, compensating for the delay
%     imposed by the designed filter (see SampledProcess.filter).
%
%     When input is an array of SampledProcesses, will iterate and treat 
%     each using the same filter, provided they all have the sampled
%     sampling frequency. Will error when input is a SampledProcess array 
%     with different sampling frequencies. To filter SampledProcess arrays 
%     with different sampling frequencies, use arrayfun (see EXAMPLES).
%
%     All inputs are passed in using name/value pairs. The name is a string
%     followed by the value (described below).
%     The order of the pairs does not matter, nor does the case.
% 
%                      Fpass
%                        v
%             |. . . . . .       -
%             | . . . . . .      _ ripple        
%             |            .                       a
%             |             .                      t
%             |            ^ .                     t
%             |            Fc .                    e
%             |                .                   n
%             |                 .                  u
%             |                  .                 a
%             |                   .                t
%             |                    .               i
%             |                     . . . . . . .  o
%             |                      . . . . . .   n
%             |                    ^               
%             |                  Fstop
%             ______________________________________
%
% INPUTS
%     Fpass - Frequency at end of passband
%     Fstop - Frequency at start of stopband
%     Fc    - Cutoff frequency at 6dB point below passband value
%     order - Filter length - 1
%
%     There are 3 different ways to call this function using combinations
%     of the above above variables.
%     1) Fpass & Fstop. This designs a minimum-order equiripple filter 
%        meeting design specs. For very stringent specifications, this may
%        fail to converge or take too long. It may be worthwhile to change
%        method to 'kaiserwin' (see below).
%     2) order & Fpass. This designs an equiripple filter attempting to
%        meet design specs using given order. 
%     3) order & Fc. This designs an equiripple filter attempting to
%        meet design specs using given order. Order should be even for an 
%        integer group delay.
%
% OPTIONAL
%     attenuation - scalar (decibels), optional, default = 60
%     ripple      - scalar (decibels), optional, default = 0.01
%     method      - string, optional, default depends on call, defined above
%     plot        - boolean, optional, default = False
%                   Plot properties of filter
%     verbose     - boolean, optional, default = False
%                   Print detailed report of filter properties
%     designOnly  - boolean, optional, default = True
%                   Design the filter without filtering SampledProcess
%
% OUTPUTS
%     self - reference to SampledProcess
%     h    - filter object (this can be re-used with SampledProcess.filter)
%     d    - filter design object
%     hft  - handle to filter plot
%
% EXAMPLES
%     s = SampledProcess(randn(1000,1),'Fs',1000);
%     % Filter process
%     s.lowpass('Fpass',20,'Fstop',40);
% 
%     % Compare equiripple default to other design algorithms
%     [~,h,d,hh] = s.lowpass('Fpass',20,'Fstop',40,'designOnly',true,...
%                  'plot',true,'verbose',true);
%     s.lowpass('Fpass',20,'Fstop',40,'designOnly',true,...
%                  'plot',hh,'method','kaiserwin','verbose',true);
%     s.lowpass('order',100,'Fc',30,'designOnly',true,'plot',hh,...
%                  'method','fircls','verbose',true);
%     legend('equiripple','kaiser','cls')
%
%     % Processing SampledProcess arrays with mixed sampling frequencies
%     s(1) = SampledProcess(randn(1000,1),'Fs',1000);
%     s(2) = SampledProcess(randn(2000,1),'Fs',2000);
%     arrayfun(@(x) x.lowpass('Fpass',20,'Fstop',40),s,'uni',0);
%
%     SEE ALSO
%     bandpass, bandstop, highpass, filter, filtfilt

%     $ Copyright (C) 2016 Brian Lau <brian.lau@upmc.fr> $
%     Released under the BSD license. The license and most recent version
%     of the code can be found on GitHub:
%     https://github.com/brian-lau/Process
function [self,h,d,hft] = lowpass(self,varargin)

if nargin < 2
   error('SampledProcess:lowpass:InputValue',...
      'Must at least specify ''Fc'' and ''order''.');
end

Fs = unique([self.Fs]);
if numel(Fs) > 1
   error('SampledProcess:lowpass:InputValue',...
      strcat('Cannot calculate common filter for different sampling frequencies.\n',...
      'Use arrayfun if you really want to calculate a different filter for each element.'));
end

p = inputParser;
p.KeepUnmatched = true;
addParameter(p,'Fpass',[],@isnumeric);
addParameter(p,'Fstop',[],@isnumeric);
addParameter(p,'Fc',[],@isnumeric);
addParameter(p,'order',[],@isnumeric);
addParameter(p,'attenuation',60,@isnumeric); % Stopband attenuation in dB
addParameter(p,'ripple',0.01,@isnumeric); % Passband ripple in dB
addParameter(p,'method','',@ischar);
addParameter(p,'plot',false,@(x) isscalar(x) || isa(x,'sigtools.fvtool'));
addParameter(p,'verbose',false,@(x) islogical(x) || isscalar(x));
addParameter(p,'designOnly',false,@(x) islogical(x) || isscalar(x));
parse(p,varargin{:});
par = p.Results;
designPars = p.Unmatched;

for i = 1:numel(self)
   %------- Add to function queue ----------
   if isQueueable(self(i))
      addToQueue(self(i),par);
      if self(i).deferredEval
         continue;
      end
   end
   %----------------------------------------
   
   if i == 1
      if isempty(par.order) % minimum-order filter
         assert(~isempty(par.Fpass)&&~isempty(par.Fstop),...
            'Minimum order filter requires Fpass and Fstop to be specified.');
         d = fdesign.lowpass('Fp,Fst,Ap,Ast',...
            par.Fpass,par.Fstop,par.ripple,par.attenuation,Fs);
      else % specified-order filter
         if ~isempty(par.Fpass) && isempty(par.Fstop)
            d = fdesign.lowpass('N,Fp,Ap,Ast',...
               par.order,par.Fpass,par.ripple,par.attenuation,Fs);
         elseif ~isempty(par.Fpass) && ~isempty(par.Fstop)
            d = fdesign.lowpass('N,Fp,Fst,Ap',...
               par.order,par.Fpass,par.Fstop,par.ripple,Fs);
         elseif ~isempty(par.Fc) % 6dB cutoff
            d = fdesign.lowpass('N,Fc,Ap,Ast',...
               par.order,par.Fc,par.ripple,par.attenuation,Fs);
         else
            error('SampledProcess:lowpass:InputValue',...
               'Incomplete filter design specification');
         end
      end
      
      if isempty(par.method)
         dm = designmethods(d,'default');
         do = designoptions(d,dm{1});
         if isfield(do,'MinOrder')
            % Force even order for integer group delay
            h = design(d,'MinOrder','even');
         else
            h = design(d);
         end
      else
         try
            h = design(d,par.method,designPars);
         catch err
            if strcmp(err.identifier,...
                  'signal:fdesign:abstracttype:superdesign:invalidDesignMethod')
               n = designmethods(d);
               msg = sprintf(' %s, ',n{:});
               err2 = MException('SampledProcess:lowpass:InputValue',...
                  strcat('For this parameter sequence, valid methods are restricted to: ',...
                  msg));
            else
               err2 = MException('SampledProcess:lowpass:InputValue',...
                  strcat('Unknown parameters for method: ',par.method));
            end
            err = addCause(err2,err);
            throw(err);
         end
      end
   end % end filter design

   if ~par.designOnly
      self(i).filter(h);
   end
end

if isa(par.plot,'sigtools.fvtool') || par.plot
   if islogical(par.plot) || isnumeric(par.plot) || ~isvalid(par.plot)
      hft = fvtool(h);
   else
      addfilter(par.plot,h);
      hft = par.plot;
   end
elseif nargout == 4
   hft = [];
end

if par.verbose
   info(h,'long');
end
