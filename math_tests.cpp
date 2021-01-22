#include "gtest/gtest.h"
#include <numeric>
#include <vector>

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

};

class math_tests : public testing::Test {

public:

    Math math;
};

TEST_F(math_tests, add_function_should_add_up_two_integers) {
    ASSERT_EQ(math.add(2,4), 6);
}

TEST_F(math_tests, add_function_should_add_up_two_real_numbers) {
    ASSERT_EQ(math.add(2.5, 2.5), 5.0);
}

TEST_F(math_tests, add_function_should_add_up_an_integer_with_a_real_number) {
    ASSERT_EQ(math.add(2.2, 4), 6.2);
}

TEST_F(math_tests, add_function_should_add_up_a_real_number_with_an_integer) {
    ASSERT_EQ(math.add(4, 2.2), 6.2);
}

TEST_F(math_tests, add_function_should_add_up_a_vector_of_real_numbers) {
    auto vector = std::vector<double>{1,2,3,4};
    ASSERT_EQ(math.add(vector), 10);
}

TEST_F(math_tests, add_function_should_add_up_an_array_of_real_numbers) {
    auto arr = std::array<double, 4>{1,2,3,4};
    ASSERT_EQ(math.add(arr), 10);
}

TEST_F(math_tests, add_function_should_add_up_an_initializer_list) {
    auto init_list = {1,2,3,4};
    ASSERT_EQ(math.add(init_list), 10);
}