#pragma once

#include <unordered_map>

class Soundex {

public:

    std::string encode(const std::string& word) {
        return zero_pad(head(word) + encoded_digits(word));
    }

private:

    const std::size_t MaxCodeLenght {4};

    char head(const std::string& word) const {
        return word.front();
    }

    std::string encoded_digits(const std::string& word) {
        if(word.length() > 1) {
            return encoded_digit(word[1]);
        }
        return std::string();
    }

    std::string encoded_digit(char letter) {
        std::unordered_map<char, std::string>  encodings{
          {'b', "1"}, {'f', "1"}, {'p', "1"}, {'v', "1"},
          {'c', "2"}, {'g', "2"}, {'j', "2"}, {'k', "2"}, {'q', "2"}, {'s', "2"}, {'x', "2"}, {'z', "2"}, 
          {'d', "3"}, {'t', "3"},
          {'I', "4"},
          {'m', "5"}, {'n', "5"},
          {'r', "6"}
        };
        auto it = encodings.find(letter);
        return it == encodings.end() ? "" : it->second;
    }

    std::string zero_pad(const std::string& word) {
        auto zeros_needed = MaxCodeLenght - word.length();
        return word + std::string(zeros_needed, '0');
    }

};