set terminal postscript
set title "ROC curve"
set datafile separator ","
set xlabel "X"
set xrange [0:1.1]
set yrange [0:1.1]
set ylabel "Y"
set output "roc.ps"
plot "roc.csv" title "" with filledcu x1
