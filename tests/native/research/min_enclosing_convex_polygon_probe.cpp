// Opt-in research probe for cv::minEnclosingConvexPolygon.
//
// Geometry does not bind minEnclosingConvexPolygon: its released native
// implementations can read out of bounds for finite input. See the Task 016
// section of docs/versioned-features-research.md.
//
// This is not one of the default native tests. scripts/run_native_tests.sh
// builds only tests/native/*.cpp, and no Alire project, test suite or CI job
// builds this file. Run it through
// scripts/run_min_enclosing_polygon_research.py, which builds it against a
// chosen OpenCV installation, runs exactly one case per child process under
// a timeout, and classifies each outcome without calling OpenCV itself.
//
// Usage:
//   min_enclosing_convex_polygon_probe [options] --case
//       Read one case from standard input: k, then binary32 points written
//       as XXXXXXXX:YYYYYYYY bit patterns of 8 hexadecimal digits each.
//   min_enclosing_convex_polygon_probe [options] --fuzz SEED ITERATION
//       Regenerate one case of the Task 016 fuzz campaign. Its generator
//       uses std::mt19937 with libstdc++'s uniform distributions, whose
//       algorithms the C++ standard leaves to the implementation, so cases
//       regenerate identically only with libstdc++. The input is printed as
//       bit patterns, so any case can be frozen in the corpus.
//   min_enclosing_convex_polygon_probe [options] --circle N RADIUS K
//       N binary32 points (float)(RADIUS * cos(a)), (float)(RADIUS * sin(a))
//       with a = 2 * pi * i / N in binary64, i = 0 .. N - 1.
//   min_enclosing_convex_polygon_probe [options] --arc N RADIUS SPAN K
//       The same, with a = SPAN * i / (N - 1).
//       The Task 016 fixtures were generated this way; the frozen corpus
//       records their bit patterns, so it does not depend on libm.
//
// Options:
//   --input-depth f32|i32  Pass CV_32FC2 points (the default), or CV_32SC2
//                          points when every coordinate is integral.
//   --fuzz-k K             With --fuzz, keep the generated points but use K;
//                          the campaign itself only generated k >= 4.
//   --triangle-oracle      After a returned result, also run
//                          cv::minEnclosingTriangle on CV_32S points when
//                          every coordinate is integral.
//   --address-space-mb N   Apply RLIMIT_AS before the native call; 0, the
//                          default, applies no limit.
//   --generate-only        Print the input and stop before any native call.
//
// Output is line-oriented: a record name followed by key=value fields, with
// free text percent-encoded. Everything before the native call is flushed,
// so it survives a crash. Exit status: 0 returned, 10 cv::Exception,
// 11 std::exception, 12 other exception, 64 usage error, 65 malformed input,
// 66 resource-limit failure, 67 probe failure outside the native call.

#include <opencv2/core.hpp>
#include <opencv2/core/utils/logger.hpp>
#if CV_VERSION_MAJOR >= 5
#include <opencv2/geometry.hpp>
#else
#include <opencv2/imgproc.hpp>
#endif

#include <dlfcn.h>
#include <sys/resource.h>
#include <unistd.h>

#include <algorithm>
#include <cerrno>
#include <chrono>
#include <cinttypes>
#include <climits>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <iostream>
#include <random>
#include <string>
#include <vector>

namespace {

constexpr int exit_returned = 0;
constexpr int exit_cv_exception = 10;
constexpr int exit_std_exception = 11;
constexpr int exit_other_exception = 12;
constexpr int exit_usage = 64;
constexpr int exit_bad_input = 65;
constexpr int exit_resource = 66;
constexpr int exit_probe_failure = 67;

// Bounds the input, and with it the probe's own output.
constexpr std::size_t max_points = 4096;
constexpr long max_fuzz_iteration = 1000000;

#if defined(__SANITIZE_ADDRESS__)
constexpr int asan_enabled = 1;
#else
constexpr int asan_enabled = 0;
#endif

#if defined(_GLIBCXX_ASSERTIONS)
constexpr int glibcxx_assertions_enabled = 1;
#else
constexpr int glibcxx_assertions_enabled = 0;
#endif

#if defined(__OPTIMIZE__)
constexpr int optimized = 1;
#else
constexpr int optimized = 0;
#endif

#if defined(NDEBUG)
constexpr int ndebug = 1;
#else
constexpr int ndebug = 0;
#endif

enum class Source { none, standard_input, fuzz, circle, arc };

struct Options
{
    Source source = Source::none;
    unsigned fuzz_seed = 0;
    int fuzz_iteration = 0;
    bool fuzz_k_given = false;
    long fuzz_k = 0;
    long generated_points = 0;
    double radius = 0.0;
    double span = 0.0;
    long generated_k = 0;
    bool integer_depth = false;
    bool triangle_oracle = false;
    bool generate_only = false;
    long address_space_mb = 0;
};

struct Case
{
    int k = 0;
    std::vector<cv::Point2f> points;
};

std::uint32_t bits_of(float value)
{
    std::uint32_t bits = 0;
    std::memcpy(&bits, &value, sizeof bits);
    return bits;
}

std::uint64_t bits_of(double value)
{
    std::uint64_t bits = 0;
    std::memcpy(&bits, &value, sizeof bits);
    return bits;
}

float float_from_bits(std::uint32_t bits)
{
    float value = 0.0f;
    std::memcpy(&value, &bits, sizeof value);
    return value;
}

// Percent-encodes free text so that it stays one field without spaces.
std::string encode(const std::string &text)
{
    static const char hex[] = "0123456789ABCDEF";
    std::string result;
    for (const char c : text) {
        const unsigned char byte = static_cast<unsigned char>(c);
        const bool plain = (byte >= '0' && byte <= '9')
            || (byte >= 'A' && byte <= 'Z') || (byte >= 'a' && byte <= 'z')
            || byte == '.' || byte == '_' || byte == '-' || byte == '/'
            || byte == '+' || byte == ',' || byte == ':';
        if (plain) {
            result += c;
        } else {
            result += '%';
            result += hex[byte >> 4];
            result += hex[byte & 15];
        }
    }
    return result;
}

bool parse_long(const char *text, long low, long high, long &value)
{
    if (text == nullptr || *text == '\0') {
        return false;
    }
    errno = 0;
    char *end = nullptr;
    const long parsed = std::strtol(text, &end, 10);
    if (errno != 0 || *end != '\0' || parsed < low || parsed > high) {
        return false;
    }
    value = parsed;
    return true;
}

bool parse_finite(const char *text, double &value)
{
    if (text == nullptr || *text == '\0') {
        return false;
    }
    errno = 0;
    char *end = nullptr;
    const double parsed = std::strtod(text, &end);
    if (errno != 0 || *end != '\0' || !std::isfinite(parsed)) {
        return false;
    }
    value = parsed;
    return true;
}

bool parse_hex32(const std::string &text, std::size_t first,
                 std::uint32_t &value)
{
    value = 0;
    for (std::size_t i = first; i < first + 8; ++i) {
        const char c = text[i];
        std::uint32_t digit = 0;
        if (c >= '0' && c <= '9') {
            digit = static_cast<std::uint32_t>(c - '0');
        } else if (c >= 'a' && c <= 'f') {
            digit = static_cast<std::uint32_t>(c - 'a' + 10);
        } else if (c >= 'A' && c <= 'F') {
            digit = static_cast<std::uint32_t>(c - 'A' + 10);
        } else {
            return false;
        }
        value = (value << 4) | digit;
    }
    return true;
}

bool read_case(std::istream &input, Case &result, std::string &error)
{
    std::string token;
    long k = 0;
    if (!(input >> token)
        || !parse_long(token.c_str(), INT_MIN, INT_MAX, k)) {
        error = "missing or malformed k";
        return false;
    }
    result.k = static_cast<int>(k);
    while (input >> token) {
        std::uint32_t x = 0;
        std::uint32_t y = 0;
        if (token.size() != 17 || token[8] != ':'
            || !parse_hex32(token, 0, x) || !parse_hex32(token, 9, y)) {
            error = "malformed point " + token.substr(0, 40);
            return false;
        }
        if (result.points.size() == max_points) {
            error = "more than " + std::to_string(max_points) + " points";
            return false;
        }
        result.points.emplace_back(float_from_bits(x), float_from_bits(y));
    }
    return true;
}

// The Task 016 fuzz generator, kept unchanged so that the campaign's seeds
// and iterations still identify the same inputs.
void make_fuzz_case(std::mt19937 &rng, std::vector<cv::Point2f> &in, int &k,
                    int &s, double &scale)
{
    std::uniform_int_distribution<int> count(4, 40);
    std::uniform_int_distribution<int> shape(0, 4);
    std::uniform_real_distribution<double> unit(0.0, 1.0);
    const double scales[] = {1e-3, 1e-2, 1.0, 1e3, 1e6};
    const int n = count(rng);
    s = shape(rng);
    scale = scales[rng() % 5];
    in.assign(static_cast<std::size_t>(n), cv::Point2f());
    for (int i = 0; i < n; i++) {
        double x, y;
        if (s == 0) { // random cloud
            x = unit(rng);
            y = unit(rng);
        } else if (s == 1) { // points on a circle
            const double a = 2 * CV_PI * unit(rng);
            x = std::cos(a);
            y = std::sin(a);
        } else if (s == 2) { // thin sliver
            x = unit(rng);
            y = 1e-3 * unit(rng);
        } else if (s == 3) { // integer grid
            x = (double)(rng() % 7);
            y = (double)(rng() % 7);
        } else { // regular polygon, parallel sides possible
            const double a = 2 * CV_PI * i / n;
            x = std::cos(a);
            y = std::sin(a);
        }
        in[static_cast<std::size_t>(i)] =
            cv::Point2f((float)(x * scale), (float)(y * scale));
    }
    k = 4 + (int)(rng() % (unsigned)std::max(1, n - 4));
}

// The Task 016 circle and arc generators.
std::vector<cv::Point2f> make_circular(long n, double radius, double span,
                                       bool closed)
{
    std::vector<cv::Point2f> points(static_cast<std::size_t>(n));
    for (long i = 0; i < n; ++i) {
        const double a = closed ? 2.0 * CV_PI * static_cast<double>(i)
                / static_cast<double>(n)
                                : span * static_cast<double>(i)
                / static_cast<double>(n - 1);
        points[static_cast<std::size_t>(i)] =
            cv::Point2f(static_cast<float>(radius * std::cos(a)),
                        static_cast<float>(radius * std::sin(a)));
    }
    return points;
}

void executable_marker() {}

template <typename Function>
bool find_object(Function *function, Dl_info &info)
{
    const void *address = nullptr;
    static_assert(sizeof function == sizeof address, "function pointer size");
    std::memcpy(&address, &function, sizeof address);
    return dladdr(address, &info) != 0;
}

// Names the loaded object, executable or shared library, that defines
// function, so that a run records which implementation it measured. glibc
// reports the main program by its argv[0], so an implementation compiled
// into the probe itself is recognized by its load base instead and named
// "main-executable".
template <typename Function>
std::string object_containing(Function *function)
{
    Dl_info info{};
    Dl_info executable{};
    if (!find_object(function, info) || info.dli_fname == nullptr) {
        return "unknown";
    }
    if (find_object(&executable_marker, executable)
        && info.dli_fbase == executable.dli_fbase) {
        return "main-executable";
    }
    return info.dli_fname;
}

std::string executable_path()
{
    char path[4096];
    const ssize_t length = readlink("/proc/self/exe", path, sizeof path - 1);
    if (length <= 0) {
        return "unknown";
    }
    path[length] = '\0';
    return path;
}

bool integral_points(const std::vector<cv::Point2f> &points,
                     std::vector<cv::Point> &result)
{
    result.clear();
    result.reserve(points.size());
    for (const cv::Point2f &point : points) {
        const float coordinates[] = {point.x, point.y};
        for (const float c : coordinates) {
            if (!std::isfinite(c) || std::trunc(c) != c
                || c < -2147483648.0f || c >= 2147483648.0f) {
                return false;
            }
        }
        result.emplace_back(static_cast<int>(point.x),
                            static_cast<int>(point.y));
    }
    return true;
}

void print_point(const char *record, std::size_t index,
                 const cv::Point2f &point)
{
    std::printf("%s i=%zu x=%08" PRIx32 " y=%08" PRIx32 " xd=%.9g yd=%.9g\n",
                record, index, bits_of(point.x), bits_of(point.y),
                static_cast<double>(point.x), static_cast<double>(point.y));
}

// Prints a native point-set result as a shape record and, when it is a
// continuous CV_32FC2 vector, one record per vertex in native order.
void print_polygon(const std::string &record, const cv::Mat &polygon)
{
    const int count = polygon.empty() ? 0 : polygon.checkVector(2, CV_32F);
    std::printf("%s_shape rows=%d cols=%d type=%d empty=%d count=%d "
                "continuous=%d\n",
                record.c_str(), polygon.rows, polygon.cols, polygon.type(),
                polygon.empty() ? 1 : 0, count,
                polygon.isContinuous() ? 1 : 0);
    if (count > 0 && polygon.isContinuous()) {
        const cv::Point2f *vertices = polygon.ptr<cv::Point2f>();
        for (int i = 0; i < count; ++i) {
            print_point(record.c_str(), static_cast<std::size_t>(i),
                        vertices[i]);
        }
    }
}

void run_triangle_oracle(bool all_integral,
                         const std::vector<cv::Point> &integral)
{
    if (!all_integral) {
        std::printf("oracle kind=triangle outcome=skipped "
                    "reason=non_integral_input\n");
        return;
    }
    std::printf("oracle_call object=%s\n",
                encode(object_containing(&cv::minEnclosingTriangle)).c_str());
    std::fflush(stdout);
    try {
        cv::Mat triangle;
        const double area = cv::minEnclosingTriangle(integral, triangle);
        std::printf("oracle kind=triangle outcome=returned area=%.17g "
                    "area_bits=%016" PRIx64 "\n",
                    area, bits_of(area));
        print_polygon("oracle_vertex", triangle);
    } catch (const cv::Exception &e) {
        std::printf("oracle kind=triangle outcome=cv_exception code=%d "
                    "message=%s\n",
                    e.code, encode(e.err).c_str());
    }
}

bool parse_options(int argc, char **argv, Options &options,
                   std::string &error)
{
    for (int i = 1; i < argc; ++i) {
        const std::string argument = argv[i];
        const auto value = [&]() -> const char * {
            if (i + 1 >= argc) {
                error = argument + " needs a value";
                return nullptr;
            }
            return argv[++i];
        };
        const bool source_argument = argument == "--case"
            || argument == "--fuzz" || argument == "--circle"
            || argument == "--arc";
        if (source_argument && options.source != Source::none) {
            error = "only one input source may be given";
            return false;
        }
        if (argument == "--circle" || argument == "--arc") {
            const bool arc = argument == "--arc";
            options.source = arc ? Source::arc : Source::circle;
            const char *count = value();
            if (count == nullptr
                || !parse_long(count, arc ? 2 : 1,
                               static_cast<long>(max_points),
                               options.generated_points)) {
                error = argument + " needs a point count in "
                    + (arc ? "2" : "1") + " .. "
                    + std::to_string(max_points);
                return false;
            }
            const char *radius = value();
            if (radius == nullptr || !parse_finite(radius, options.radius)) {
                error = argument + " needs a finite RADIUS";
                return false;
            }
            if (arc) {
                const char *span = value();
                if (span == nullptr || !parse_finite(span, options.span)) {
                    error = "--arc needs a finite SPAN";
                    return false;
                }
            }
            const char *k = value();
            if (k == nullptr
                || !parse_long(k, INT_MIN, INT_MAX, options.generated_k)) {
                error = argument + " needs an int K";
                return false;
            }
        } else if (argument == "--case" || argument == "--fuzz") {
            if (argument == "--case") {
                options.source = Source::standard_input;
                continue;
            }
            options.source = Source::fuzz;
            const char *seed = value();
            long parsed_seed = 0;
            if (seed == nullptr
                || !parse_long(seed, 0, static_cast<long>(UINT_MAX),
                               parsed_seed)) {
                error = "--fuzz needs a SEED in 0 .. UINT_MAX";
                return false;
            }
            const char *iteration = value();
            long parsed_iteration = 0;
            if (iteration == nullptr
                || !parse_long(iteration, 0, max_fuzz_iteration,
                               parsed_iteration)) {
                error = "--fuzz needs an ITERATION in 0 .. "
                    + std::to_string(max_fuzz_iteration);
                return false;
            }
            options.fuzz_seed = static_cast<unsigned>(parsed_seed);
            options.fuzz_iteration = static_cast<int>(parsed_iteration);
        } else if (argument == "--input-depth") {
            const char *depth = value();
            if (depth == nullptr) {
                return false;
            }
            if (std::strcmp(depth, "f32") == 0) {
                options.integer_depth = false;
            } else if (std::strcmp(depth, "i32") == 0) {
                options.integer_depth = true;
            } else {
                error = "--input-depth must be f32 or i32";
                return false;
            }
        } else if (argument == "--triangle-oracle") {
            options.triangle_oracle = true;
        } else if (argument == "--fuzz-k") {
            const char *k = value();
            if (k == nullptr
                || !parse_long(k, INT_MIN, INT_MAX, options.fuzz_k)) {
                error = "--fuzz-k needs an int K";
                return false;
            }
            options.fuzz_k_given = true;
        } else if (argument == "--address-space-mb") {
            const char *limit = value();
            if (limit == nullptr
                || !parse_long(limit, 0, 1L << 30,
                               options.address_space_mb)) {
                error = "--address-space-mb needs a value in 0 .. 2**30";
                return false;
            }
        } else if (argument == "--generate-only") {
            options.generate_only = true;
        } else {
            error = "unknown argument " + argument;
            return false;
        }
    }
    if (options.source == Source::none) {
        error = "one of --case, --fuzz, --circle and --arc is required";
        return false;
    }
    if (options.fuzz_k_given && options.source != Source::fuzz) {
        error = "--fuzz-k needs --fuzz";
        return false;
    }
    return true;
}

int run(int argc, char **argv)
{
    Options options;
    std::string error;
    if (!parse_options(argc, argv, options, error)) {
        std::fprintf(stderr, "usage error: %s\n", error.c_str());
        return exit_usage;
    }

    std::printf("probe format=1 compile_version=%s\n", CV_VERSION);
    std::printf("build asan=%d glibcxx_assertions=%d optimized=%d ndebug=%d "
                "compiler=%s\n",
                asan_enabled, glibcxx_assertions_enabled, optimized, ndebug,
                encode(__VERSION__).c_str());
    std::printf(
        "runtime version=%s implementation_object=%s core_object=%s "
        "executable=%s\n",
        encode(cv::getVersionString()).c_str(),
        encode(object_containing(&cv::minEnclosingConvexPolygon)).c_str(),
        encode(object_containing(&cv::getVersionString)).c_str(),
        encode(executable_path()).c_str());

    const char *depth = options.integer_depth ? "i32" : "f32";
    Case input;
    if (options.source == Source::fuzz) {
        std::mt19937 rng(options.fuzz_seed);
        int shape = 0;
        double scale = 0.0;
        for (int iteration = 0; iteration <= options.fuzz_iteration;
             ++iteration) {
            make_fuzz_case(rng, input.points, input.k, shape, scale);
        }
        const int generated_k = input.k;
        if (options.fuzz_k_given) {
            input.k = static_cast<int>(options.fuzz_k);
        }
        std::printf("input source=fuzz seed=%u iteration=%d shape=%d "
                    "scale=%.17g generated_k=%d k=%d n=%zu depth=%s\n",
                    options.fuzz_seed, options.fuzz_iteration, shape, scale,
                    generated_k, input.k, input.points.size(), depth);
    } else if (options.source == Source::circle
               || options.source == Source::arc) {
        const bool closed = options.source == Source::circle;
        input.k = static_cast<int>(options.generated_k);
        input.points = make_circular(options.generated_points,
                                     options.radius, options.span, closed);
        std::printf("input source=%s n=%zu radius=%.17g span=%.17g k=%d "
                    "depth=%s\n",
                    closed ? "circle" : "arc", input.points.size(),
                    options.radius, closed ? 2.0 * CV_PI : options.span,
                    input.k, depth);
    } else {
        if (!read_case(std::cin, input, error)) {
            std::printf("error kind=malformed_input message=%s\n",
                        encode(error).c_str());
            std::fprintf(stderr, "malformed input: %s\n", error.c_str());
            return exit_bad_input;
        }
        std::printf("input source=case k=%d n=%zu depth=%s\n", input.k,
                    input.points.size(), depth);
    }
    for (std::size_t i = 0; i < input.points.size(); ++i) {
        print_point("point", i, input.points[i]);
    }

    std::vector<cv::Point> integral;
    const bool all_integral = integral_points(input.points, integral);
    if (options.integer_depth && !all_integral) {
        std::printf("error kind=malformed_input "
                    "message=i32%%20input%%20needs%%20integral%%20points\n");
        std::fprintf(stderr, "--input-depth i32 needs integral points\n");
        return exit_bad_input;
    }
    if (options.generate_only) {
        std::printf("end\n");
        return exit_returned;
    }

    if (options.address_space_mb > 0) {
        const rlim_t bytes =
            static_cast<rlim_t>(options.address_space_mb) * 1024 * 1024;
        const struct rlimit limit = {bytes, bytes};
        if (setrlimit(RLIMIT_AS, &limit) != 0) {
            std::fprintf(stderr, "setrlimit(RLIMIT_AS) failed: %s\n",
                         std::strerror(errno));
            return exit_resource;
        }
    }

    std::printf("call begin\n");
    std::fflush(stdout);

    cv::Mat polygon;
    double area = 0.0;
    int status = exit_returned;
    std::string failure;
    const auto start = std::chrono::steady_clock::now();
    try {
        if (options.integer_depth) {
            area = cv::minEnclosingConvexPolygon(integral, polygon, input.k);
        } else {
            area =
                cv::minEnclosingConvexPolygon(input.points, polygon, input.k);
        }
    } catch (const cv::Exception &e) {
        status = exit_cv_exception;
        failure = "result outcome=cv_exception code=" + std::to_string(e.code)
            + " function=" + encode(e.func) + " line="
            + std::to_string(e.line) + " message=" + encode(e.err);
    } catch (const std::exception &e) {
        status = exit_std_exception;
        failure = "result outcome=std_exception message=" + encode(e.what());
    } catch (...) {
        status = exit_other_exception;
        failure = "result outcome=other_exception";
    }
    const double seconds = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - start).count();
    struct rusage usage{};
    getrusage(RUSAGE_SELF, &usage);
    std::printf("resources wall_seconds=%.6f max_rss_kib=%ld\n", seconds,
                usage.ru_maxrss);

    if (status != exit_returned) {
        std::printf("%s\nend\n", failure.c_str());
        return status;
    }
    std::printf("result outcome=returned area=%.17g area_bits=%016" PRIx64
                "\n",
                area, bits_of(area));
    print_polygon("vertex", polygon);
    if (options.triangle_oracle) {
        run_triangle_oracle(all_integral, integral);
    }
    std::printf("end\n");
    return exit_returned;
}

} // namespace

int main(int argc, char **argv)
{
    cv::utils::logging::setLogLevel(cv::utils::logging::LOG_LEVEL_WARNING);
    try {
        return run(argc, argv);
    } catch (const std::exception &e) {
        std::fflush(stdout);
        std::fprintf(stderr, "probe failure: %s\n", e.what());
    } catch (...) {
        std::fflush(stdout);
        std::fprintf(stderr, "probe failure: unknown exception\n");
    }
    return exit_probe_failure;
}