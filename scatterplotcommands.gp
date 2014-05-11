set terminal postscript
set title "Scatter"
set datafile separator ","
set xlabel "X"
set ylabel "Y"
set output "scatter.ps"
plot "scatter.csv" title "" with points
