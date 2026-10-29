function ds = loadCoco(splitDir)
%LOADCOCO Wczytuje podzbiór COCO z Roboflow do prostej tablicy struktur.
%   ds(i).file   - pełna ścieżka do obrazu
%   ds(i).boxes  - Nx4 [x y w h] (piksele, konwencja COCO)
%   ds(i).labels - Nx1 indeks klasy (1=choco, 2=cookie, 3=corn)

raw = jsondecode(fileread(fullfile(splitDir, "_annotations.coco.json")));

imgs = raw.images;
if iscell(imgs), imgs = [imgs{:}]; end
anns = raw.annotations;
if iscell(anns), anns = [anns{:}]; end

imgIds  = [anns.image_id];
catIds  = [anns.category_id];
allBox  = reshape([anns.bbox], 4, []).';

ds = struct("file", {}, "boxes", {}, "labels", {});
for i = 1:numel(imgs)
    sel = imgIds == imgs(i).id;
    ds(i).file   = fullfile(splitDir, imgs(i).file_name);
    ds(i).boxes  = allBox(sel, :);
    % kategoria 0 ("creams") to nieużywana nadkategoria Roboflow
    ds(i).labels = catIds(sel).';
end
end
