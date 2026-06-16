CXX ?= g++
CXXFLAGS ?= -std=c++11 -O2 -Wall -Wextra -pthread

all: ctrlsys_smoke_test bno055_init_start

ctrlsys_smoke_test: ctrlsys_smoke_test.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

bno055_init_start: bno055_init_start.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

clean:
	rm -f ctrlsys_smoke_test bno055_init_start

.PHONY: all clean
