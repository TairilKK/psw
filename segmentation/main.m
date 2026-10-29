%% Segmentacja przekąsek (choco / cookie / corn) na zbiorze Mlekolaki v3
% Uruchomienie z katalogu głównego repozytorium:
%   matlab -batch "run('segmentation/main.m')"

clear; close all;
here = fileparts(mfilename("fullpath"));
addpath(here);
dataDir = fullfile(here, "..", "data", "Mlekolaki.v3i.coco");
outDir  = fullfile(here, "results");
if ~isfolder(outDir), mkdir(outDir); end

classNames = ["choco", "cookie", "corn"];
colors = [0.85 0.2 0.2; 
          0.2 0.5 0.95; 
          0.95 0.85 0.1];

%% 1) Wczytanie danych
train = loadCoco(fullfile(dataDir, "train"));
valid = loadCoco(fullfile(dataDir, "valid"));
test  = loadCoco(fullfile(dataDir, "test"));
fprintf("train %d | valid %d | test %d images\n", numel(train), numel(valid), numel(test));

%% 2) Uczenie modelu koloru na ramkach ze zbioru treningowego
lut = trainPixelClassifier(train);
save(fullfile(outDir, "colorLUT.mat"), "lut");

%% 3) Segmentacja i ocena na zbiorach walidacyjnym i testowym
for split = ["valid", "test"]
    ds = eval(split);
    tot.tp = zeros(1,3); tot.fp = zeros(1,3); tot.fn = zeros(1,3);
    countErr = zeros(numel(ds), 1);
    for i = 1:numel(ds)
        I = imread(ds(i).file);
        [labelMap, ~, inst] = segmentImage(I, lut);
        pb = reshape([inst.bbox], 4, []).';
        pl = [inst.label].';
        r = evaluateDetections(pb, pl, ds(i).boxes, ds(i).labels, 0.5);
        tot.tp = tot.tp + r.tp; tot.fp = tot.fp + r.fp; tot.fn = tot.fn + r.fn;
        countErr(i) = abs(numel(inst) - numel(ds(i).labels)) / numel(ds(i).labels);

        % Wizualizacja: nakładka | przewidziane ramki | ramki wzorcowe
        ov = labeloverlay(I, labelMap, "Colormap", colors, "Transparency", 0.45);
        pr = insertShape(I, "rectangle", pb, "Color", colors(pl, :) * 255, "LineWidth", 2);
        gt = insertShape(I, "rectangle", ds(i).boxes, ...
            "Color", colors(ds(i).labels, :) * 255, "LineWidth", 2);
        [~, name] = fileparts(ds(i).file);
        imwrite([ov, pr, gt], fullfile(outDir, split + "_" + extractBefore(name, "_jpg") + ".jpg"));
    end

    P = tot.tp ./ (tot.tp + tot.fp); R = tot.tp ./ (tot.tp + tot.fn);
    F = 2 * P .* R ./ (P + R);
    fprintf("\n== %s (IoU >= 0.5) ==\n", split);
    fprintf("%-8s %6s %6s %6s %5s %5s %5s\n", "class", "prec", "recall", "F1", "TP", "FP", "FN");
    for c = 1:3
        fprintf("%-8s %6.3f %6.3f %6.3f %5d %5d %5d\n", classNames(c), P(c), R(c), F(c), ...
            tot.tp(c), tot.fp(c), tot.fn(c));
    end
    Pa = sum(tot.tp) / sum(tot.tp + tot.fp); Ra = sum(tot.tp) / sum(tot.tp + tot.fn);
    fprintf("%-8s %6.3f %6.3f %6.3f\n", "all", Pa, Ra, 2*Pa*Ra/(Pa+Ra));
    fprintf("mean relative count error: %.1f%%\n", 100 * mean(countErr));
end
