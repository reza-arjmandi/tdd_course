#pragma once

#include <string>

class StringUtil {

public:

    static std::string tail(const std::string& word) {
        if (word.length() == 0) {
            return "";
        }
        return word.substr(1);
    }

    static char head(const std::string& word) {
        return word.front();
    }

    static std::string zero_pad(
        const std::string& word, std::size_t max_code_length) {
        auto zeros_needed = max_code_length - word.length();
        return word + std::string(zeros_needed, '0');
    }

};