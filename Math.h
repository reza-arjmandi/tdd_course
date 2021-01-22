#pragma once

class Math{

public:

    template<typename T, typename U>
    auto add(T a, U b) {
        return a+b;
    }

    template<typename ContainerType>
    auto add(ContainerType& container) {
        return std::accumulate(std::begin(container), std::end(container), 0.0);
    }

    template<typename T, typename... TARGS>
    auto add(T var, TARGS... args) {
        return var + add(args...);
    }

};