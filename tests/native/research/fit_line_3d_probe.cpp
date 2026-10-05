// Research only. One native fitLine call per process; use the Python runner.
// Protocol FL3D1: depth model parameter reps aeps count, then XYZ triples.
// f32 coordinates are exactly eight hex digits; i32 are decimal integers.
// Scalars are binary64 hexadecimal strings (strtod), including inf/nan.
// Exit: 0 return, 10 cv exception, 11 std exception, 12 other, 65 bad input.
#include <opencv2/core.hpp>
#if CV_VERSION_MAJOR == 4
#include <opencv2/imgproc.hpp>
#elif CV_VERSION_MAJOR == 5
#include <opencv2/geometry.hpp>
#else
#error Unsupported OpenCV major
#endif
#include <dlfcn.h>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>

namespace {
std::string quote(const std::string& s) {
    std::ostringstream out;
    out << '"';
    for (unsigned char c : s) {
        if (c == '"' || c == '\\') out << '\\' << c;
        else if (c < 32) out << "\\u00" << std::hex << std::setw(2)
                             << std::setfill('0') << unsigned(c);
        else out << c;
    }
    out << '"';
    return out.str();
}
std::string bits(float f) {
    std::uint32_t b;
    std::memcpy(&b, &f, 4);
    std::ostringstream s;
    s << std::hex << std::setw(8) << std::setfill('0') << b;
    return s.str();
}
float parse_float(const std::string& s) {
    if (s.size() != 8 || s.find_first_not_of("0123456789abcdefABCDEF")
        != std::string::npos) throw std::invalid_argument("bad f32 bits");
    auto b = static_cast<std::uint32_t>(std::stoul(s, nullptr, 16));
    float f;
    std::memcpy(&f, &b, 4);
    return f;
}
double scalar(const std::string& s) {
    char* end = nullptr;
    double d = std::strtod(s.c_str(), &end);
    if (end == s.c_str() || *end) throw std::invalid_argument("bad scalar");
    return d;
}
int model(const std::string& s) {
    if (s == "L2") return cv::DIST_L2;
    if (s == "L1") return cv::DIST_L1;
    if (s == "L12") return cv::DIST_L12;
    if (s == "Fair") return cv::DIST_FAIR;
    if (s == "Welsch") return cv::DIST_WELSCH;
    if (s == "Huber") return cv::DIST_HUBER;
    throw std::invalid_argument("bad model");
}
}

int main(int argc, char** argv) {
    static_assert(sizeof(float) == 4 && std::numeric_limits<float>::is_iec559,
                  "binary32 required");
    static_assert(sizeof(int) == 4, "32-bit native int required");
    if (argc == 2 && std::string(argv[1]) == "--rng") {
        cv::RNG rng(UINT64_MAX);
        std::cout << "[";
        for (int i = 0; i < 16; ++i) {
            if (i) std::cout << ',';
            std::cout << rng.next();
        }
        std::cout << "]\n";
        return 0;
    }
    try {
        if (argc != 1) throw std::invalid_argument("unexpected argument");
        std::string magic, depth, distance, param, reps, aeps;
        long long count;
        if (!(std::cin >> magic >> depth >> distance >> param >> reps >> aeps
              >> count) || magic != "FL3D1" || count < 1 || count > 1000000
            || (depth != "f32" && depth != "i32"))
            throw std::invalid_argument("bad header/count/depth");
        int dist = model(distance);
        double p = scalar(param), r = scalar(reps), a = scalar(aeps);
        cv::Mat points(static_cast<int>(count), 1,
                       depth == "f32" ? CV_32FC3 : CV_32SC3);
        std::ostringstream input;
        input << '[';
        for (int i = 0; i < count; ++i) {
            if (i) input << ',';
            input << '[';
            for (int j = 0; j < 3; ++j) {
                if (j) input << ',';
                std::string s;
                if (!(std::cin >> s)) throw std::invalid_argument("short input");
                if (depth == "f32") {
                    float f = parse_float(s);
                    auto& pt = points.ptr<cv::Point3f>()[i];
                    (j == 0 ? pt.x : j == 1 ? pt.y : pt.z) = f;
                    input << quote(bits(f));
                } else {
                    std::size_t used;
                    auto v = std::stoll(s, &used);
                    if (used != s.size() || v < INT32_MIN || v > INT32_MAX)
                        throw std::invalid_argument("bad i32");
                    auto& pt = points.ptr<cv::Point3i>()[i];
                    (j == 0 ? pt.x : j == 1 ? pt.y : pt.z) = static_cast<int>(v);
                    input << v;
                }
            }
            input << ']';
        }
        std::string extra;
        if (std::cin >> extra) throw std::invalid_argument("trailing input");
        input << ']';
        Dl_info info{};
        dladdr(reinterpret_cast<void*>(static_cast<void (*)(cv::InputArray,
            cv::OutputArray, int, double, double, double)>(&cv::fitLine)), &info);
        std::cout << "{\"kind\":\"input\",\"protocol\":\"FL3D1\","
                  << "\"compile\":" << quote(CV_VERSION)
                  << ",\"runtime\":" << quote(cv::getVersionString())
                  << ",\"object\":" << quote(info.dli_fname ? info.dli_fname : "")
                  << ",\"depth\":" << quote(depth) << ",\"count\":" << count
                  << ",\"model\":" << quote(distance)
                  << ",\"scalars\":[" << quote(param) << ',' << quote(reps)
                  << ',' << quote(aeps) << "],\"points\":" << input.str()
                  << "}\n" << std::flush;
        auto start = std::chrono::steady_clock::now();
        cv::Mat line;
        try {
            cv::fitLine(points, line, dist, p, r, a);
        } catch (const cv::Exception& e) {
            std::cout << "{\"kind\":\"cv_exception\",\"code\":" << e.code
                      << ",\"message\":" << quote(e.what()) << "}\n";
            return 10;
        } catch (const std::exception& e) {
            std::cout << "{\"kind\":\"std_exception\",\"message\":"
                      << quote(e.what()) << "}\n";
            return 11;
        } catch (...) {
            std::cout << "{\"kind\":\"other_exception\"}\n";
            return 12;
        }
        double seconds = std::chrono::duration<double>(
            std::chrono::steady_clock::now() - start).count();
        bool finite = true;
        double norm2 = 0;
        std::cout << "{\"kind\":\"result\",\"type\":" << line.type()
                  << ",\"rows\":" << line.rows << ",\"cols\":" << line.cols
                  << ",\"bits\":[";
        if (line.type() != CV_32F || line.total() != 6)
            throw std::runtime_error("unexpected result layout");
        for (int i = 0; i < 6; ++i) {
            float f = line.ptr<float>()[i];
            if (i) std::cout << ',';
            std::cout << quote(bits(f));
            finite = finite && std::isfinite(f);
            if (i < 3) norm2 += double(f) * f;
        }
        std::cout << "],\"finite\":" << (finite ? "true" : "false")
                  << ",\"norm\":" << (std::isfinite(norm2)
                      ? std::to_string(std::sqrt(norm2)) : "null")
                  << ",\"seconds\":" << std::setprecision(17) << seconds
                  << "}\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << e.what() << '\n';
        return 65;
    }
}