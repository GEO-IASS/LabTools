function self = reset(self)
% Reset windows & offsets to state when object was created if it
% has not been chopped, otherwise to when it was chopped.
%
% SEE ALSO
% setInclusiveWindow
for i = 1:numel(self)
   self(i).window = self(i).window_;
   % Directly apply window in case window_ = window
   self(i).offset = 'windowIsReset';
   applyWindow(self(i));
   self(i).offset = self(i).offset_;
end
