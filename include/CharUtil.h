#pragma once

#include <string>

class CharUtil{

public:

    static std::string upper(char ch) {
        return std::string(1, std::toupper(static_cast<unsigned char>(ch)));
    }

    static char lower(char ch) {
        return std::tolower(static_cast<unsigned char>(ch));
    }

    static bool is_vowel(char letter) {
        return 
            std::string("aeiouy").find(CharUtil::lower(letter)) 
            != std::string::npos;
    }

};