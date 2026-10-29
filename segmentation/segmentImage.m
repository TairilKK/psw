function [labelMap, instMap, inst] = segmentImage(I, lut, opts)
%SEGMENTIMAGE Segmentacja semantyczna i instancji przekąsek na białym tle.
%   labelMap - HxW uint8, 0 = tło, 1 = choco, 2 = cookie, 3 = corn
%   instMap  - HxW double, 0 = tło, k = k-ty obiekt
%   inst     - tablica struktur z polami label, bbox [x y w h], area

arguments
    I
    lut
    opts.minArea (1,1) double = 120
    opts.smooth (1,1) double = 5
    opts.hMin (1,1) double = 2
end

% 1) Klasyfikacja koloru każdego piksela obrazu po korekcji oświetlenia.
[J, roi] = preprocess(I);
bins = size(lut, 1);
q = idivide(uint16(J), uint16(256/bins)) + 1;
labelMap = lut(sub2ind(size(lut), double(q(:,:,1)), double(q(:,:,2)), double(q(:,:,3))));

% 2) Wygładzanie przestrzenne: głosowanie większościowe usuwa szum (np.
%    kawałki czekolady na ciastkach oznaczone jako "choco").
labelMap = modefilt(labelMap, [opts.smooth opts.smooth]);

% 3) Obszar zainteresowania: odrzucenie ciemnego materiału / stołu wokół kartek.
labelMap(~roi) = 0;

% 4) Dla każdej klasy: oczyszczenie maski i rozdzielenie stykających się
%    obiektów transformatą wododziałową (watershed).
instMap = zeros(size(labelMap));
inst = struct("label", {}, "bbox", {}, "area", {});
for c = 1:3
    m = labelMap == c;
    m = imopen(m, strel("disk", 2));
    m = imfill(m, "holes");
    m = bwareaopen(m, opts.minArea);

    D = -bwdist(~m);
    D = imimposemin(D, imextendedmin(D, opts.hMin));
    W = watershed(D);
    m(W == 0) = false;
    m = bwareaopen(m, opts.minArea);

    cc = bwconncomp(m, 4);
    st = regionprops(cc, "BoundingBox", "Area");
    for k = 1:cc.NumObjects
        n = numel(inst) + 1;
        instMap(cc.PixelIdxList{k}) = n;
        inst(n).label = c;
        bb = st(k).BoundingBox;           % [x y w h], indeksowanie od 0.5
        inst(n).bbox = [bb(1) - 0.5, bb(2) - 0.5, bb(3), bb(4)];
        inst(n).area = st(k).Area;
    end
    labelMap(labelMap == c & ~m) = 0;
end
end
