#pragma once

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
            return encoded_digit();
        }
        return std::string();
    }

    std::string encoded_digit() {
        return "1";
    }

    std::string zero_pad(const std::string& word) {
        auto zeros_needed = MaxCodeLenght - word.length();
        return word + std::string(zeros_needed, '0');
    }

};