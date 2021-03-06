function [descriptors, output_index] = S_feat_extraction_jointcolor_N2(oriImgs, options)
%
%   
       numScales = 3;
       BH = 8;  
       StepH = 4;
       BW = 16;  
       StepW = 8;
       colorBins = [8, 8, 8];
       feattype = 'HSV';
       
       if nargin >=2
         if isfield(options,'numScales') 
             numScales = options.numScales;
         end
          
         if isfield(options,'BH')
             BH = options.BH;
         end
         
         if isfield(options,'StepH') 
             StepH = options.StepH;
         end
         
         if isfield(options,'BW')
             BW = options.BW;
         end
         
         if isfield(options,'StepW') 
            StepW = options.StepW;
         end
         
         if isfield(options,'colorBins') 
             colorBins = options.colorBins;
         end
         
         if isfield(options,'feattype')
             feattype = options.feattype;
         end
         
         if isfield(options, 'RowStep')
             RowStep = options.RowStep;
         end
         
         if isfield(options, 'RowWidth')
             RowWidth = options.RowWidth;
         end
         
       end
       
          totalBins = prod(colorBins);
          numImgs = size(oriImgs,4);
          images = zeros(size(oriImgs));
          
        %%%%%%%% color histogram %%%%%%%%
        for i = 1 : numImgs
            I = oriImgs(:,:,:,i);
            if strcmp(feattype, 'HSV') ==1
                   I = rgb2hsv(I);
            elseif strcmp(feattype, 'LAB') == 1
                   I = rgb2lab(I);
            elseif strcmp(feattype, 'RGB') ==1
                   I = double(I)/255; 
            else
                   error('no processing for such channel!');
            end
            
            I(:,:,1) = min( floor( I(:,:,1) * colorBins(1) ), colorBins(1)-1 );
            I(:,:,2) = min( floor( I(:,:,2) * colorBins(2) ), colorBins(2)-1 );
            I(:,:,3) = min( floor( I(:,:,3) * colorBins(3) ), colorBins(3)-1 );
            images(:,:,:,i) = I;  
        end
        
          minRow = 1;
          minCol = 1;
          priBlocknum = 0;
          descriptors = [];
          output_index = [];
        
        for i =1:numScales
             patterns = images(:,:,3,:) * colorBins(2) * colorBins(1)... 
              + images(:,:,2,:)*colorBins(1) + images(:,:,1,:); % HSV  %%%  �� Histogram ���б���
             patterns = reshape(patterns, [], numImgs); 
             
             height = size(images,1);
             width  = size(images,2);
             maxRow = height - BH + 1;
             maxCol = width - BW +1;
             
             [cols, rows] = meshgrid(minCol:StepW:maxCol, minRow:StepH:maxRow);
             cols = cols'; 
             rows = rows';
             cols = cols(:); 
             rows = rows(:);
             numBlocks = length(cols);
             numBlocksCol = length(minCol:StepW:maxCol);
             numBlocksRow = length(minRow:StepH:maxRow);
             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
             if numBlocks <= 1
                  Col =  minCol:StepW:maxCol;
                  Row =  minRow:StepH:maxRow;
                  
                  if(length(Col)<=1)
                         Col = 1; 
                  end
                  
                  if(length(Row)<=1)
                         Row = 1;
                  end
                  
                  [cols, rows] = meshgrid(Col,Row);
                  cols = cols'; 
                  rows = rows';
                  cols = cols(:); 
                  rows = rows(:);
                  numBlocks = length(cols);
                  
                  Block_start = 1;
                  Block_end = numBlocks;
                   
                  BH = min(height, BH);
                  BW = min(width, BW);
                   
                  offset = bsxfun(@plus, (0 : BH - 1)', (0 : BW - 1) * height);
                  index = sub2ind([height,width],rows,cols);
                  index = bsxfun(@plus, offset(:),index');
                  
                  patches = patterns(index(:),:);
                  patches = reshape(patches,[],numBlocks*numImgs);
                  fea = hist(patches, 0 : totalBins-1);
                  %%%%%%%%%%%%%
%                 fea  = normc(fea);
                  %%%%%%%%%%%%%%
                  fea  = reshape(fea,[], numBlocks, numImgs);
                  descriptors = cat(2, descriptors , fea);
                  curr_index = [(Block_start+priBlocknum)', (Block_end+priBlocknum)'];
                  output_index = cat(1, output_index, curr_index);
                  
             else
                  [Block_start, Block_end ] =  S_division_index( numBlocksRow,numBlocksCol,RowStep, RowWidth);
                   offset = bsxfun(@plus, (0 : BH - 1)', (0 : BW - 1) * height);
                   index = sub2ind([height,width],rows,cols);
                   index = bsxfun(@plus, offset(:),index');
                   patches = patterns(index(:),:);
                   patches = reshape(patches,[],numBlocks*numImgs);
                   fea = hist(patches, 0 : totalBins-1);
                   %%%%%%%%%%%%%
                   fea  = reshape(fea,[], numBlocks, numImgs);
                   
                   
                   descriptors = cat(2, descriptors , fea);
                   curr_index = [(Block_start+priBlocknum)', (Block_end+priBlocknum)'];
                   output_index = cat(1, output_index, curr_index);
                   priBlocknum = priBlocknum + numBlocks;
             end
             
                 if i<numScales
                   images = ColorPooling(images,'average');
                 end 
               
        end
                  descriptors = log(descriptors + 1);           
end

function outImages = ColorPooling(images, method)
    [height, width, numChannels, numImgs] = size(images);
    outImages = images;
    
    if mod(height, 2) == 1
        outImages(end, :, :, :) = [];
        height = height - 1;
    end
    
    if mod(width, 2) == 1
        outImages(:, end, :, :) = [];
        width = width - 1;
    end
    
    if height == 0 || width == 0
        error('Over scaled image: height=%d, width=%d.', height, width);
    end
    
    height = height / 2;
    width = width / 2;
    
    outImages = reshape(outImages, 2, height, 2, width, numChannels, numImgs);
    outImages = permute(outImages, [2, 4, 5, 6, 1, 3]);
    outImages = reshape(outImages, height, width, numChannels, numImgs, 2*2);
    
    if strcmp(method, 'average')
        outImages = floor(mean(outImages, 5));
    else if strcmp(method, 'max')
            outImages = max(outImages, [], 5);
        else
            error('Error pooling method: %s.', method);
        end
    end
end


