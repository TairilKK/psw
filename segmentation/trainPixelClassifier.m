function lut = trainPixelClassifier(ds, opts)
%TRAINPIXELCLASSIFIER Uczy odwzorowania kolor -> klasa na podstawie ramek.
%   Piksele obiektów są losowane z wewnętrznej elipsy każdej ramki wzorcowej
%   (próbka to głównie obiekt, a nie jego cień czy tło). Piksele tła są
%   losowane poza wszystkimi (poszerzonymi) ramkami, wewnątrz ROI papieru.
%   Kolory pochodzą z obrazu po korekcji oświetlenia. Zespół drzew (bagging)
%   jest uczony na kolorze w przestrzeni Lab, a następnie zapisywany jako
%   tablica LUT w RGB, dzięki czemu klasyfikacja całego obrazu to jedno
%   indeksowanie.
%
%   lut - tablica uint8 o rozmiarze opts.bins^3, wartość 0 = tło, 1..3 = klasa

arguments
    ds struct
    opts.perObject (1,1) double = 40
    opts.bgPerImage (1,1) double = 3000
    opts.innerScale (1,1) double = 0.5
    opts.bins (1,1) double = 64
    opts.minScore (1,1) double = 0.6
end

rng(0);
X = {}; Y = {};
for i = 1:numel(ds)
    [I, roi] = preprocess(imread(ds(i).file));
    [h, w, ~] = size(I);
    rgb = reshape(I, [], 3);
    [xx, yy] = meshgrid(1:w, 1:h);
    inAnyBox = false(h, w);

    for k = 1:size(ds(i).boxes, 1)
        b = ds(i).boxes(k, :);
        cx = b(1) + b(3)/2; cy = b(2) + b(4)/2;
        rx = opts.innerScale * b(3)/2; ry = opts.innerScale * b(4)/2;
        ell = ((xx - cx)/rx).^2 + ((yy - cy)/ry).^2 <= 1;
        idx = find(ell);
        if isempty(idx), continue; end
        idx = idx(randi(numel(idx), min(opts.perObject, numel(idx)), 1));
        X{end+1} = rgb(idx, :); %#ok<AGROW>
        Y{end+1} = repmat(ds(i).labels(k), numel(idx), 1); %#ok<AGROW>

        x0 = max(1, floor(b(1)) - 3); x1 = min(w, ceil(b(1)+b(3)) + 3);
        y0 = max(1, floor(b(2)) - 3); y1 = min(h, ceil(b(2)+b(4)) + 3);
        inAnyBox(y0:y1, x0:x1) = true;
    end

    bgIdx = find(~inAnyBox & roi);
    bgIdx = bgIdx(randi(numel(bgIdx), opts.bgPerImage, 1));
    X{end+1} = rgb(bgIdx, :); %#ok<AGROW>
    Y{end+1} = zeros(numel(bgIdx), 1); %#ok<AGROW>
end
X = vertcat(X{:}); Y = vertcat(Y{:});

feat = @(rgb) rgb2lab(double(rgb) / 255);
mdl = fitcensemble(feat(X), Y, "Method", "Bag", "NumLearningCycles", 40, ...
    "Learners", templateTree("MinLeafSize", 20));

% Zapisanie modelu jako tablicy LUT kolorów (bins^3 wpisów).
q = (0:opts.bins-1) * (256/opts.bins) + 128/opts.bins;
[R, G, B] = ndgrid(q, q, q);
[lbl, score] = predict(mdl, feat([R(:) G(:) B(:)]));
% Niepewne kolory (głównie szare cienie) traktowane są jako tło.
lbl(max(score, [], 2) < opts.minScore) = 0;
lut = reshape(uint8(lbl), opts.bins, opts.bins, opts.bins);

fprintf("Trained on %d pixels (bg %d, choco %d, cookie %d, corn %d)\n", ...
    numel(Y), sum(Y==0), sum(Y==1), sum(Y==2), sum(Y==3));
end
