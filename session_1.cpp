#include "gtest/gtest.h"
#include <numeric>
#include <vector>

#include "Math.h"

class test_fixture : public testing::Test {

public:

    Math math;
};

TEST_F(test_fixture, add_function_should_add_up_two_integers) {
    ASSERT_EQ(math.add(2,4), 6);
}

TEST_F(test_fixture, add_function_should_add_up_two_real_numbers) {
    ASSERT_EQ(math.add(2.5, 2.5), 5.0);
}

TEST_F(test_fixture, add_function_should_add_up_an_integer_with_a_real_number) {
    ASSERT_EQ(math.add(2.2, 4), 6.2);
}

TEST_F(test_fixture, add_function_should_add_up_a_real_number_with_an_integer) {
    ASSERT_EQ(math.add(4, 2.2), 6.2);
}

TEST_F(test_fixture, add_function_should_add_up_a_vector_of_real_numbers) {
    auto vector = std::vector<double>{1,2,3,4};
    ASSERT_EQ(math.add(vector), 10);
}

TEST_F(test_fixture, add_function_should_add_up_an_array_of_real_numbers) {
    auto arr = std::array<double, 4>{1,2,3,4};
    ASSERT_EQ(math.add(arr), 10);
}

TEST_F(test_fixture, add_function_should_add_up_an_initializer_list) {
    auto init_list = {1,2,3,4};
    ASSERT_EQ(math.add(init_list), 10);
}

TEST_F(test_fixture, add_function_should_takes_several_parameters) {
    ASSERT_EQ(math.add(1,2,3,4), 10);
}