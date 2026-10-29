function r = evaluateDetections(predBox, predLbl, gtBox, gtLbl, iouThr)
%EVALUATEDETECTIONS Zachłanne dopasowanie ramek w obrębie klasy przy progu IoU.
%   Zwraca tp/fp/fn dla każdej klasy (wektory 1x3).

r.tp = zeros(1, 3); r.fp = zeros(1, 3); r.fn = zeros(1, 3);
for c = 1:3
    P = predBox(predLbl == c, :);
    G = gtBox(gtLbl == c, :);
    if isempty(P) || isempty(G)
        r.fp(c) = size(P, 1); r.fn(c) = size(G, 1);
        continue
    end
    iou = bboxOverlapRatio(P, G);
    matched = 0;
    while true
        [v, idx] = max(iou(:));
        if v < iouThr, break; end
        [p, g] = ind2sub(size(iou), idx);
        iou(p, :) = 0; iou(:, g) = 0;
        matched = matched + 1;
    end
    r.tp(c) = matched;
    r.fp(c) = size(P, 1) - matched;
    r.fn(c) = size(G, 1) - matched;
end
end
