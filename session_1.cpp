#include "gtest/gtest.h"

class Math{

public:

    template<typename T>
    T add(T a, T b) {
        return a+b;
    }
};

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
