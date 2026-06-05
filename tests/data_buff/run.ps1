$currentPath = (Get-Location).Path
$work_dir = "C:\Users\JS Lab\Documents\gordo\RedPitaya\CtrlSysV3\tests\data_buff"

Remove-Item -Path $work_dir"\sim" -Recurse -Force -ErrorAction SilentlyContinue
mkdir $work_dir"\sim"

$source_dir = "C:\Users\JS Lab\Documents\gordo\RedPitaya\CtrlSysV3\source\hdl"
$tb_path = "C:\Users\JS Lab\Documents\gordo\RedPitaya\CtrlSysV3\tests\data_buff\data_buff_tb.sv"

cd $work_dir"\sim"


& "C:\Xilinx\Vivado\2024.2\bin\xvlog.bat" -sv $source_dir\config_pkg.sv $source_dir\data_buff.sv $tb_path
& "C:\Xilinx\Vivado\2024.2\bin\xelab.bat" tb -s sim -debug all
& "C:\Xilinx\Vivado\2024.2\bin\xsim.bat" sim --gui

cd $currentPath