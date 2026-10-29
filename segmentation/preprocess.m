function [J, roi] = preprocess(I)
%PREPROCESS Korekcja nierównomiernego oświetlenia i obszar zainteresowania.
%   J   - obraz z usuniętym nierównomiernym oświetleniem (papier ~ jednolicie biały)
%   roi - maska logiczna obszaru papieru (bez ciemnego materiału / stołu)

I = im2double(I);

% Estymacja oświetlenia: przekąski są ciemniejsze od papieru, więc duże
% zamknięcie w skali szarości (w połowie rozdzielczości dla szybkości)
% zastępuje je jasnością otaczającego papieru. Dzielenie przez tę estymatę
% wyrównuje cieniowanie i cienie.
small = imresize(I, 0.5);
bg = imclose(small, strel("disk", 20));
bg = imgaussfilt(bg, 8);
bg = imresize(bg, [size(I, 1) size(I, 2)]);
J = im2uint8(min(1, 0.9 * I ./ max(bg, 0.05)));

% Obszar zainteresowania: wszystko poza dużymi ciemnymi obszarami (materiał,
% stół). Otwarcie dyskiem szerszym niż przekąska zostawia tylko duże ciemne obszary.
gray = rgb2gray(I);
dark = imopen(gray < 0.3, strel("disk", 25));
roi = ~imdilate(dark, strel("disk", 6));
end
