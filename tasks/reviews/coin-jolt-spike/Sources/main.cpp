// Headless Jolt 5.6.0 coin contact spike for Poch 1441.
// Project code: no Jolt source is vendored. Build against the pinned upstream tag.

#include <Jolt/Jolt.h>
#include <Jolt/RegisterTypes.h>
#include <Jolt/Core/Factory.h>
#include <Jolt/Core/JobSystemSingleThreaded.h>
#include <Jolt/Core/TempAllocator.h>
#include <Jolt/Physics/PhysicsSettings.h>
#include <Jolt/Physics/PhysicsSystem.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Collision/ContactListener.h>
#include <Jolt/Physics/Collision/Shape/BoxShape.h>
#include <Jolt/Physics/Collision/Shape/ConvexHullShape.h>
#include <Jolt/Physics/Collision/Shape/CylinderShape.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <mutex>
#include <sstream>
#include <string>
#include <sys/resource.h>
#include <vector>

JPH_SUPPRESS_WARNINGS

using namespace JPH;
using namespace JPH::literals;

namespace {

constexpr float kScale = 50.0f;
constexpr float kCoinRadius = 0.011f * kScale;
constexpr float kCoinHalfThickness = 0.0011f * kScale;
constexpr float kCoinMass = 0.0045f;
constexpr float kGravity = 9.81f * kScale;
constexpr float kStep = 1.0f / 120.0f;
constexpr float kPenetrationLimitInternal = 0.00015f * kScale;
constexpr float kLinearRestLimit = 0.015f * kScale;
constexpr float kAngularRestLimit = 0.8f;
constexpr float kRequiredRestSeconds = 0.75f;
constexpr float kEnergyGrowthLimit = 0.01f;
constexpr int kRepeatCount = 100;

constexpr uint64_t kFloorUserData = 1;
constexpr uint64_t kLipUserData = 2;
constexpr uint64_t kDynamicUserData = 100;

namespace Layers {
constexpr ObjectLayer NonMoving = 0;
constexpr ObjectLayer Moving = 1;
constexpr ObjectLayer Count = 2;
}

namespace BroadPhaseLayers {
constexpr BroadPhaseLayer NonMoving(0);
constexpr BroadPhaseLayer Moving(1);
constexpr uint Count = 2;
}

class ObjectLayerPairFilterImpl final : public ObjectLayerPairFilter {
public:
    bool ShouldCollide(ObjectLayer first, ObjectLayer second) const override {
        if (first == Layers::NonMoving) {
            return second == Layers::Moving;
        }
        if (first == Layers::Moving) {
            return true;
        }
        return false;
    }
};

class BroadPhaseLayerInterfaceImpl final : public BroadPhaseLayerInterface {
public:
    uint GetNumBroadPhaseLayers() const override { return BroadPhaseLayers::Count; }

    BroadPhaseLayer GetBroadPhaseLayer(ObjectLayer layer) const override {
        return layer == Layers::NonMoving ? BroadPhaseLayers::NonMoving : BroadPhaseLayers::Moving;
    }
};

class ObjectVsBroadPhaseLayerFilterImpl final : public ObjectVsBroadPhaseLayerFilter {
public:
    bool ShouldCollide(ObjectLayer layer, BroadPhaseLayer broadPhase) const override {
        if (layer == Layers::NonMoving) {
            return broadPhase == BroadPhaseLayers::Moving;
        }
        return true;
    }
};

enum class ShapeKind {
    Convex12,
    Convex48,
    BoxControl,
    ExactCylinder,
};

struct SolverConfig {
    const char *name;
    float penetrationSlop;
    float speculativeDistance;
    uint velocitySteps;
    uint positionSteps;
};

// Frozen before the first run. Do not add or change entries after inspecting results.
constexpr std::array<SolverConfig, 6> kSolverConfigs {{
    {"S1-limit-slop", 0.00750f, 0.02000f, 10, 4},
    {"S2-half-slop", 0.00375f, 0.01500f, 12, 6},
    {"S3-fifth-slop", 0.00150f, 0.01000f, 16, 8},
    {"S4-tenth-slop", 0.00075f, 0.00750f, 20, 10},
    {"S5-zero-slop", 0.00000f, 0.00500f, 24, 12},
    {"S6-balanced", 0.00375f, 0.00750f, 24, 12},
}};

struct CaseSpec {
    const char *name;
    ShapeKind shape;
    int polygonSegments;
    RVec3 position;
    Quat orientation;
    Vec3 linearVelocity;
    Vec3 angularVelocity;
    float bodyFriction;
    float bodyRestitution;
    float staticFriction;
    float staticRestitution;
    bool requiresRest;
    bool requiresLipContact;
    float maximumDuration;
};

std::vector<CaseSpec> MakeCases() {
    const RVec3 calibrationPosition(0.0_r, Real((0.0011f + 0.030f) * kScale), 0.0_r);
    const Vec3 calibrationVelocity(0.0f, -0.12f * kScale, 0.0f);
    const RVec3 centralPosition(0.0_r, Real(0.048f * kScale), Real(-0.012f * kScale));
    const Vec3 centralVelocity(0.015f * kScale, -0.34f * kScale, 0.055f * kScale);

    return {
        {"coin-convex12-face", ShapeKind::Convex12, 12, calibrationPosition,
         Quat::sIdentity(), calibrationVelocity, Vec3::sZero(),
         0.60f, 0.0f, 0.65f, 0.0f, true, false, 5.0f},
        {"coin-convex48-face", ShapeKind::Convex48, 48, calibrationPosition,
         Quat::sIdentity(), calibrationVelocity, Vec3::sZero(),
         0.60f, 0.0f, 0.65f, 0.0f, true, false, 5.0f},
        {"coin-convex12-tilt3", ShapeKind::Convex12, 12, calibrationPosition,
         Quat::sRotation(Vec3::sAxisX(), 3.0f * JPH_PI / 180.0f), calibrationVelocity,
         Vec3(0.5f, 0.2f, 0.3f), 0.60f, 0.0f, 0.65f, 0.0f, true, false, 5.0f},
        {"coin-convex48-tilt3", ShapeKind::Convex48, 48, calibrationPosition,
         Quat::sRotation(Vec3::sAxisX(), 3.0f * JPH_PI / 180.0f), calibrationVelocity,
         Vec3(0.5f, 0.2f, 0.3f), 0.60f, 0.0f, 0.65f, 0.0f, true, false, 5.0f},
        {"box-control-face", ShapeKind::BoxControl, 0, calibrationPosition,
         Quat::sIdentity(), calibrationVelocity, Vec3::sZero(),
         0.60f, 0.0f, 0.65f, 0.0f, true, false, 5.0f},
        {"central-face-0deg", ShapeKind::ExactCylinder, 0, centralPosition,
         Quat::sIdentity(), centralVelocity, Vec3(4.0f, 2.0f, 6.0f),
         0.58f, 0.18f, 0.62f, 0.12f, true, false, 6.0f},
        {"central-face-minus3deg", ShapeKind::ExactCylinder, 0, centralPosition,
         Quat::sRotation(Vec3::sAxisX(), -3.0f * JPH_PI / 180.0f), centralVelocity,
         Vec3(4.0f, 2.0f, 6.0f), 0.58f, 0.18f, 0.62f, 0.12f, true, false, 6.0f},
        {"central-face-plus3deg", ShapeKind::ExactCylinder, 0, centralPosition,
         Quat::sRotation(Vec3::sAxisX(), 3.0f * JPH_PI / 180.0f), centralVelocity,
         Vec3(4.0f, 2.0f, 6.0f), 0.58f, 0.18f, 0.62f, 0.12f, true, false, 6.0f},
        {"edge-lip-78deg", ShapeKind::ExactCylinder, 0,
         RVec3(0.0_r, Real(0.043f * kScale), Real(-0.020f * kScale)),
         Quat::sRotation(Vec3::sAxisX(), 78.0f * JPH_PI / 180.0f),
         Vec3(0.02f * kScale, -0.07f * kScale, 0.52f * kScale), Vec3(10.0f, 4.0f, 3.0f),
         0.58f, 0.18f, 0.62f, 0.12f, false, true, 2.5f},
    };
}

struct ContactMeasurement final : public ContactListener {
    std::mutex mutex;
    float maximumPenetration = 0.0f;
    bool lipContact = false;
    uint64_t contactCallbacks = 0;

    void Record(const Body &first, const Body &second, const ContactManifold &manifold) {
        std::lock_guard<std::mutex> lock(mutex);
        maximumPenetration = std::max(maximumPenetration, std::max(0.0f, manifold.mPenetrationDepth));
        lipContact = lipContact || first.GetUserData() == kLipUserData || second.GetUserData() == kLipUserData;
        ++contactCallbacks;
    }

    void OnContactAdded(const Body &first, const Body &second,
                        const ContactManifold &manifold, ContactSettings &) override {
        Record(first, second, manifold);
    }

    void OnContactPersisted(const Body &first, const Body &second,
                            const ContactManifold &manifold, ContactSettings &) override {
        Record(first, second, manifold);
    }
};

struct FNV1a64 {
    uint64_t value = 1469598103934665603ULL;

    void AddBytes(const void *bytes, size_t count) {
        const auto *cursor = static_cast<const uint8_t *>(bytes);
        for (size_t index = 0; index < count; ++index) {
            value ^= cursor[index];
            value *= 1099511628211ULL;
        }
    }

    void AddFloat(float number) {
        uint32_t bits = 0;
        static_assert(sizeof(bits) == sizeof(number));
        std::memcpy(&bits, &number, sizeof(bits));
        AddBytes(&bits, sizeof(bits));
    }

    void AddBool(bool flag) {
        const uint8_t byte = flag ? 1 : 0;
        AddBytes(&byte, sizeof(byte));
    }
};

struct RunResult {
    uint64_t hash = 0;
    float maximumAnalyticFloorOverlap = 0.0f;
    float maximumContactPenetration = 0.0f;
    float maximumEnergyGrowth = 0.0f;
    float sustainedRest = 0.0f;
    bool reachedRest = false;
    bool lipContact = false;
    bool remainedContained = true;
    bool finite = true;
    uint64_t contactCallbacks = 0;
    int steps = 0;
    std::vector<double> stepMicroseconds;
};

struct CaseAggregate {
    CaseSpec spec;
    RunResult reference;
    int repeats = 0;
    int uniqueHashes = 0;
    int firstHashMismatch = -1;
    bool deterministic = false;
    bool passed = false;
};

struct ConfigAggregate {
    SolverConfig config;
    std::vector<CaseAggregate> cases;
    bool passed = false;
};

RefConst<Shape> MakeShape(const CaseSpec &spec) {
    if (spec.shape == ShapeKind::BoxControl) {
        return new BoxShape(Vec3(kCoinRadius, kCoinHalfThickness, kCoinRadius), 0.0f);
    }
    if (spec.shape == ShapeKind::ExactCylinder) {
        return new CylinderShape(kCoinHalfThickness, kCoinRadius, 0.0f);
    }

    Array<Vec3> points;
    points.reserve(size_t(spec.polygonSegments) * 2);
    for (int side = -1; side <= 1; side += 2) {
        for (int segment = 0; segment < spec.polygonSegments; ++segment) {
            const float angle = 2.0f * JPH_PI * float(segment) / float(spec.polygonSegments);
            points.push_back(Vec3(kCoinRadius * std::cos(angle),
                                  float(side) * kCoinHalfThickness,
                                  kCoinRadius * std::sin(angle)));
        }
    }
    ConvexHullShapeSettings settings(points, 0.0f);
    settings.mHullTolerance = 1.0e-5f;
    auto result = settings.Create();
    if (result.HasError()) {
        std::cerr << "Convex hull creation failed: " << result.GetError() << "\n";
        return nullptr;
    }
    return result.Get();
}

float VerticalExtent(const CaseSpec &spec, QuatArg rotation) {
    const Vec3 localUp = rotation.Conjugated() * Vec3::sAxisY();
    if (spec.shape == ShapeKind::BoxControl) {
        return kCoinRadius * std::abs(localUp.GetX())
             + kCoinHalfThickness * std::abs(localUp.GetY())
             + kCoinRadius * std::abs(localUp.GetZ());
    }

    const float axial = kCoinHalfThickness * std::abs(localUp.GetY());
    if (spec.shape == ShapeKind::ExactCylinder) {
        const float radial = kCoinRadius * std::sqrt(localUp.GetX() * localUp.GetX()
                                                   + localUp.GetZ() * localUp.GetZ());
        return axial + radial;
    }

    float radialSupport = 0.0f;
    for (int segment = 0; segment < spec.polygonSegments; ++segment) {
        const float angle = 2.0f * JPH_PI * float(segment) / float(spec.polygonSegments);
        radialSupport = std::max(radialSupport,
            kCoinRadius * (localUp.GetX() * std::cos(angle) + localUp.GetZ() * std::sin(angle)));
    }
    return axial + radialSupport;
}

float MechanicalEnergy(const CaseSpec &spec, RVec3Arg position, QuatArg rotation,
                       Vec3Arg linearVelocity, Vec3Arg angularVelocity) {
    const float y = float(position.GetY());
    const float translational = 0.5f * kCoinMass * linearVelocity.LengthSq();
    const Vec3 axis = rotation * Vec3::sAxisY();
    const float axialSpeed = angularVelocity.Dot(axis);
    const float radialSpeedSquared = std::max(0.0f, angularVelocity.LengthSq() - axialSpeed * axialSpeed);

    float radialInertia = 0.0f;
    float axialInertia = 0.0f;
    if (spec.shape == ShapeKind::BoxControl) {
        const float width = 2.0f * kCoinRadius;
        const float height = 2.0f * kCoinHalfThickness;
        radialInertia = kCoinMass * (height * height + width * width) / 12.0f;
        axialInertia = kCoinMass * (width * width + width * width) / 12.0f;
    } else {
        const float thickness = 2.0f * kCoinHalfThickness;
        radialInertia = kCoinMass * (3.0f * kCoinRadius * kCoinRadius + thickness * thickness) / 12.0f;
        axialInertia = 0.5f * kCoinMass * kCoinRadius * kCoinRadius;
    }
    const float rotational = 0.5f * radialInertia * radialSpeedSquared
                           + 0.5f * axialInertia * axialSpeed * axialSpeed;
    return kCoinMass * kGravity * y + translational + rotational;
}

void HashState(FNV1a64 &hash, RVec3Arg position, QuatArg rotation,
               Vec3Arg linearVelocity, Vec3Arg angularVelocity, bool active) {
    hash.AddFloat(float(position.GetX()));
    hash.AddFloat(float(position.GetY()));
    hash.AddFloat(float(position.GetZ()));
    hash.AddFloat(rotation.GetX());
    hash.AddFloat(rotation.GetY());
    hash.AddFloat(rotation.GetZ());
    hash.AddFloat(rotation.GetW());
    hash.AddFloat(linearVelocity.GetX());
    hash.AddFloat(linearVelocity.GetY());
    hash.AddFloat(linearVelocity.GetZ());
    hash.AddFloat(angularVelocity.GetX());
    hash.AddFloat(angularVelocity.GetY());
    hash.AddFloat(angularVelocity.GetZ());
    hash.AddBool(active);
}

void AddStaticBox(BodyInterface &bodies, Vec3Arg halfExtent, RVec3Arg position,
                  QuatArg rotation, float friction, float restitution, uint64_t userData,
                  std::vector<BodyID> &staticBodies) {
    BodyCreationSettings settings(new BoxShape(halfExtent, 0.0f), position, rotation,
                                  EMotionType::Static, Layers::NonMoving);
    settings.mFriction = friction;
    settings.mRestitution = restitution;
    settings.mUserData = userData;
    BodyID id = bodies.CreateAndAddBody(settings, EActivation::DontActivate);
    staticBodies.push_back(id);
}

RunResult RunCase(const SolverConfig &config, const CaseSpec &spec, bool collectTimings) {
    BroadPhaseLayerInterfaceImpl broadPhase;
    ObjectVsBroadPhaseLayerFilterImpl objectVsBroadPhase;
    ObjectLayerPairFilterImpl objectPairs;
    PhysicsSystem system;
    system.Init(64, 0, 64, 64, broadPhase, objectVsBroadPhase, objectPairs);
    system.SetGravity(Vec3(0.0f, -kGravity, 0.0f));

    PhysicsSettings physicsSettings = system.GetPhysicsSettings();
    physicsSettings.mPenetrationSlop = config.penetrationSlop;
    physicsSettings.mSpeculativeContactDistance = config.speculativeDistance;
    physicsSettings.mNumVelocitySteps = config.velocitySteps;
    physicsSettings.mNumPositionSteps = config.positionSteps;
    physicsSettings.mDeterministicSimulation = true;
    physicsSettings.mConstraintWarmStart = true;
    physicsSettings.mTimeBeforeSleep = 0.5f;
    physicsSettings.mPointVelocitySleepThreshold = kLinearRestLimit;
    system.SetPhysicsSettings(physicsSettings);

    ContactMeasurement contacts;
    system.SetContactListener(&contacts);
    TempAllocatorImpl allocator(4 * 1024 * 1024);
    JobSystemSingleThreaded jobs(cMaxPhysicsJobs);
    BodyInterface &bodies = system.GetBodyInterface();
    std::vector<BodyID> staticBodies;

    // V1 tray shifted so the floor top is y = 0.
    AddStaticBox(bodies, Vec3(4.5f, 0.1f, 3.5f), RVec3(0.0_r, -0.1_r, 0.0_r),
                 Quat::sIdentity(), spec.staticFriction, spec.staticRestitution,
                 kFloorUserData, staticBodies);
    AddStaticBox(bodies, Vec3(0.125f, 0.95f, 3.625f), RVec3(-4.625_r, 0.85_r, 0.0_r),
                 Quat::sIdentity(), spec.staticFriction, spec.staticRestitution, 3, staticBodies);
    AddStaticBox(bodies, Vec3(0.125f, 0.95f, 3.625f), RVec3(4.625_r, 0.85_r, 0.0_r),
                 Quat::sIdentity(), spec.staticFriction, spec.staticRestitution, 4, staticBodies);
    AddStaticBox(bodies, Vec3(4.75f, 0.95f, 0.125f), RVec3(0.0_r, 0.85_r, -3.625_r),
                 Quat::sIdentity(), spec.staticFriction, spec.staticRestitution, 5, staticBodies);
    AddStaticBox(bodies, Vec3(4.75f, 0.15f, 0.75f), RVec3(0.0_r, 0.5_r, 3.2_r),
                 Quat::sRotation(Vec3::sAxisX(), -25.0f * JPH_PI / 180.0f),
                 spec.staticFriction, spec.staticRestitution, kLipUserData, staticBodies);

    RefConst<Shape> shape = MakeShape(spec);
    if (shape == nullptr) {
        RunResult failed;
        failed.finite = false;
        return failed;
    }

    BodyCreationSettings bodySettings(shape, spec.position, spec.orientation,
                                      EMotionType::Dynamic, Layers::Moving);
    bodySettings.mMotionQuality = EMotionQuality::LinearCast;
    bodySettings.mFriction = spec.bodyFriction;
    bodySettings.mRestitution = spec.bodyRestitution;
    bodySettings.mLinearDamping = 0.0f;
    bodySettings.mAngularDamping = 0.0f;
    bodySettings.mOverrideMassProperties = EOverrideMassProperties::CalculateInertia;
    bodySettings.mMassPropertiesOverride.mMass = kCoinMass;
    bodySettings.mUserData = kDynamicUserData;
    BodyID dynamicID = bodies.CreateAndAddBody(bodySettings, EActivation::Activate);
    bodies.SetLinearAndAngularVelocity(dynamicID, spec.linearVelocity, spec.angularVelocity);
    system.OptimizeBroadPhase();

    RunResult result;
    FNV1a64 hash;
    const float initialEnergy = MechanicalEnergy(spec, spec.position, spec.orientation,
                                                 spec.linearVelocity, spec.angularVelocity);
    float maximumEnergy = initialEnergy;
    float restDuration = 0.0f;
    const int maximumSteps = int(std::ceil(spec.maximumDuration / kStep));

    for (int step = 0; step < maximumSteps; ++step) {
        const auto before = std::chrono::steady_clock::now();
        system.Update(kStep, 1, &allocator, &jobs);
        const auto after = std::chrono::steady_clock::now();
        if (collectTimings) {
            result.stepMicroseconds.push_back(
                std::chrono::duration<double, std::micro>(after - before).count());
        }

        RVec3 position;
        Quat rotation;
        Vec3 linearVelocity;
        Vec3 angularVelocity;
        bodies.GetPositionAndRotation(dynamicID, position, rotation);
        bodies.GetLinearAndAngularVelocity(dynamicID, linearVelocity, angularVelocity);
        const bool active = bodies.IsActive(dynamicID);
        HashState(hash, position, rotation, linearVelocity, angularVelocity, active);

        const float extent = VerticalExtent(spec, rotation);
        const bool aboveFloor = std::abs(float(position.GetX())) <= 4.5f + kCoinRadius
                             && std::abs(float(position.GetZ())) <= 3.5f + kCoinRadius;
        if (aboveFloor) {
            result.maximumAnalyticFloorOverlap = std::max(
                result.maximumAnalyticFloorOverlap,
                std::max(0.0f, extent - float(position.GetY())));
        }

        const float energy = MechanicalEnergy(spec, position, rotation, linearVelocity, angularVelocity);
        maximumEnergy = std::max(maximumEnergy, energy);
        const bool finite = position.IsClose(RVec3(position), 0.0_r)
                         && std::isfinite(float(position.GetX()))
                         && std::isfinite(float(position.GetY()))
                         && std::isfinite(float(position.GetZ()))
                         && std::isfinite(rotation.GetX()) && std::isfinite(rotation.GetY())
                         && std::isfinite(rotation.GetZ()) && std::isfinite(rotation.GetW())
                         && std::isfinite(linearVelocity.LengthSq())
                         && std::isfinite(angularVelocity.LengthSq())
                         && std::isfinite(energy);
        result.finite = result.finite && finite;
        result.remainedContained = result.remainedContained
            && std::abs(float(position.GetX())) <= 4.5f + kCoinRadius
            && float(position.GetZ()) >= -3.5f - kCoinRadius
            && float(position.GetZ()) <= 3.5f + kCoinRadius
            && float(position.GetY()) >= -1.0f;

        const bool quiet = linearVelocity.Length() < kLinearRestLimit
                        && angularVelocity.Length() < kAngularRestLimit;
        restDuration = quiet ? restDuration + kStep : 0.0f;
        result.sustainedRest = std::max(result.sustainedRest, restDuration);
        result.steps = step + 1;

        if (spec.requiresRest && restDuration + 1.0e-6f >= kRequiredRestSeconds) {
            result.reachedRest = true;
            break;
        }
    }

    result.hash = hash.value;
    result.maximumContactPenetration = contacts.maximumPenetration;
    result.lipContact = contacts.lipContact;
    result.contactCallbacks = contacts.contactCallbacks;
    result.maximumEnergyGrowth = std::max(0.0f, maximumEnergy - initialEnergy)
                               / std::max(std::abs(initialEnergy), 1.0e-9f);

    bodies.RemoveBody(dynamicID);
    bodies.DestroyBody(dynamicID);
    for (BodyID id : staticBodies) {
        bodies.RemoveBody(id);
        bodies.DestroyBody(id);
    }
    return result;
}

double Percentile(std::vector<double> values, double percentile) {
    if (values.empty()) {
        return 0.0;
    }
    std::sort(values.begin(), values.end());
    const size_t index = std::min(values.size() - 1,
        size_t(std::ceil(percentile * double(values.size()))) - 1);
    return values[index];
}

double ToProductMillimeters(float internalLength) {
    return double(internalLength) / double(kScale) * 1000.0;
}

std::string HexHash(uint64_t value) {
    std::ostringstream stream;
    stream << "0x" << std::hex << std::setw(16) << std::setfill('0') << value;
    return stream.str();
}

const char *ShapeName(ShapeKind kind) {
    switch (kind) {
    case ShapeKind::Convex12: return "convex-hull-12";
    case ShapeKind::Convex48: return "convex-hull-48";
    case ShapeKind::BoxControl: return "box-control";
    case ShapeKind::ExactCylinder: return "jolt-cylinder";
    }
    return "unknown";
}

bool CasePasses(const CaseSpec &spec, const RunResult &result, bool deterministic) {
    const float maximumOverlap = std::max(result.maximumAnalyticFloorOverlap,
                                          result.maximumContactPenetration);
    return deterministic
        && result.finite
        && result.remainedContained
        && maximumOverlap <= kPenetrationLimitInternal
        && result.maximumEnergyGrowth <= kEnergyGrowthLimit
        && (!spec.requiresRest || result.reachedRest)
        && (!spec.requiresLipContact || result.lipContact);
}

std::string PlatformName() {
#if defined(JPH_PLATFORM_IOS)
    return "ios-arm64";
#elif defined(JPH_PLATFORM_MACOS)
    return "macos-arm64";
#else
    return "unknown";
#endif
}

void WriteJSON(const std::string &path, const std::vector<ConfigAggregate> &configs,
               const std::vector<double> &allStepTimes, double wallSeconds,
               double userCPUSeconds, double systemCPUSeconds) {
    bool solverGreen = false;
    std::string selectedConfig;
    for (const auto &config : configs) {
        if (config.passed && !solverGreen) {
            solverGreen = true;
            selectedConfig = config.config.name;
        }
    }

    std::ofstream output(path);
    if (!output) {
        std::cerr << "Unable to open output: " << path << "\n";
        std::exit(3);
    }
    output << std::fixed << std::setprecision(6);
    output << "{\n";
    output << "  \"schemaVersion\": 1,\n";
    output << "  \"joltTag\": \"v5.6.0\",\n";
    output << "  \"joltCommit\": \"e77f175595e64cb44218cc9d9d56fc365ad0e36a\",\n";
    output << "  \"license\": \"MIT\",\n";
    output << "  \"licenseSHA256\": \"800abe35d64ad9defd636ff1ee8c961e06f0ebca3ef8d10083e8aa0e8ef86ac3\",\n";
    output << "  \"platform\": \"" << PlatformName() << "\",\n";
    output << "  \"crossPlatformDeterministic\": true,\n";
    output << "  \"physicsScale\": " << kScale << ",\n";
    output << "  \"fixedStepSeconds\": " << kStep << ",\n";
    output << "  \"repeatCountPerCase\": " << kRepeatCount << ",\n";
    output << "  \"penetrationLimitMillimeters\": 0.150000,\n";
    output << "  \"solverVerdict\": \"" << (solverGreen ? "GREEN" : "RED") << "\",\n";
    output << "  \"selectedConfig\": " << (solverGreen ? "\"" + selectedConfig + "\"" : "null") << ",\n";
    output << "  \"productionVerdict\": \"RED\",\n";
    output << "  \"productionBlockers\": [\"no real iOS 17 device run\", \"no nine-coin 60 FPS measurement\", \"no iOS device energy measurement\", \"no SwiftUI/RealityKit integration\"],\n";
    output << "  \"performance\": {\n";
    output << "    \"scope\": \"single-body headless macOS architecture gate\",\n";
    output << "    \"stepSamples\": " << allStepTimes.size() << ",\n";
    output << "    \"p50Microseconds\": " << Percentile(allStepTimes, 0.50) << ",\n";
    output << "    \"p95Microseconds\": " << Percentile(allStepTimes, 0.95) << ",\n";
    output << "    \"p99Microseconds\": " << Percentile(allStepTimes, 0.99) << ",\n";
    output << "    \"maximumMicroseconds\": "
           << (allStepTimes.empty() ? 0.0 : *std::max_element(allStepTimes.begin(), allStepTimes.end())) << ",\n";
    output << "    \"wallSeconds\": " << wallSeconds << ",\n";
    output << "    \"userCPUSeconds\": " << userCPUSeconds << ",\n";
    output << "    \"systemCPUSeconds\": " << systemCPUSeconds << "\n";
    output << "  },\n";
    output << "  \"configs\": [\n";

    for (size_t configIndex = 0; configIndex < configs.size(); ++configIndex) {
        const auto &aggregate = configs[configIndex];
        const auto &config = aggregate.config;
        output << "    {\n";
        output << "      \"name\": \"" << config.name << "\",\n";
        output << "      \"penetrationSlopInternal\": " << config.penetrationSlop << ",\n";
        output << "      \"penetrationSlopMillimeters\": " << ToProductMillimeters(config.penetrationSlop) << ",\n";
        output << "      \"speculativeDistanceInternal\": " << config.speculativeDistance << ",\n";
        output << "      \"velocitySteps\": " << config.velocitySteps << ",\n";
        output << "      \"positionSteps\": " << config.positionSteps << ",\n";
        output << "      \"verdict\": \"" << (aggregate.passed ? "GREEN" : "RED") << "\",\n";
        output << "      \"cases\": [\n";
        for (size_t caseIndex = 0; caseIndex < aggregate.cases.size(); ++caseIndex) {
            const auto &caseAggregate = aggregate.cases[caseIndex];
            const auto &result = caseAggregate.reference;
            const float maximumOverlap = std::max(result.maximumAnalyticFloorOverlap,
                                                  result.maximumContactPenetration);
            output << "        {\n";
            output << "          \"name\": \"" << caseAggregate.spec.name << "\",\n";
            output << "          \"shape\": \"" << ShapeName(caseAggregate.spec.shape) << "\",\n";
            output << "          \"verdict\": \"" << (caseAggregate.passed ? "GREEN" : "RED") << "\",\n";
            output << "          \"hash\": \"" << HexHash(result.hash) << "\",\n";
            output << "          \"repeats\": " << caseAggregate.repeats << ",\n";
            output << "          \"uniqueHashes\": " << caseAggregate.uniqueHashes << ",\n";
            output << "          \"firstHashMismatch\": " << caseAggregate.firstHashMismatch << ",\n";
            output << "          \"deterministic\": " << (caseAggregate.deterministic ? "true" : "false") << ",\n";
            output << "          \"maximumAnalyticFloorOverlapMillimeters\": "
                   << ToProductMillimeters(result.maximumAnalyticFloorOverlap) << ",\n";
            output << "          \"maximumContactManifoldPenetrationMillimeters\": "
                   << ToProductMillimeters(result.maximumContactPenetration) << ",\n";
            output << "          \"gatedMaximumOverlapMillimeters\": "
                   << ToProductMillimeters(maximumOverlap) << ",\n";
            output << "          \"maximumMechanicalEnergyGrowthRatio\": " << result.maximumEnergyGrowth << ",\n";
            output << "          \"sustainedRestSeconds\": " << result.sustainedRest << ",\n";
            output << "          \"reachedRequiredRest\": " << (result.reachedRest ? "true" : "false") << ",\n";
            output << "          \"lipContact\": " << (result.lipContact ? "true" : "false") << ",\n";
            output << "          \"remainedContained\": " << (result.remainedContained ? "true" : "false") << ",\n";
            output << "          \"finite\": " << (result.finite ? "true" : "false") << ",\n";
            output << "          \"contactCallbacks\": " << result.contactCallbacks << ",\n";
            output << "          \"steps\": " << result.steps << "\n";
            output << "        }" << (caseIndex + 1 == aggregate.cases.size() ? "\n" : ",\n");
        }
        output << "      ]\n";
        output << "    }" << (configIndex + 1 == configs.size() ? "\n" : ",\n");
    }
    output << "  ]\n";
    output << "}\n";
}

double TimevalSeconds(const timeval &value) {
    return double(value.tv_sec) + double(value.tv_usec) / 1'000'000.0;
}

} // namespace

int main(int argc, char **argv) {
    if (argc != 2) {
        std::cerr << "usage: coin-jolt-spike <output.json>\n";
        return 2;
    }

    RegisterDefaultAllocator();
    Factory::sInstance = new Factory();
    RegisterTypes();

    const auto wallStart = std::chrono::steady_clock::now();
    rusage usageStart {};
    getrusage(RUSAGE_SELF, &usageStart);

    std::vector<ConfigAggregate> aggregates;
    std::vector<double> allStepTimes;
    const std::vector<CaseSpec> cases = MakeCases();

    for (const SolverConfig &config : kSolverConfigs) {
        ConfigAggregate configAggregate {config, {}, true};
        for (const CaseSpec &spec : cases) {
            CaseAggregate caseAggregate {spec};
            std::vector<uint64_t> hashes;
            hashes.reserve(kRepeatCount);
            for (int repeat = 0; repeat < kRepeatCount; ++repeat) {
                RunResult result = RunCase(config, spec, repeat == 0);
                hashes.push_back(result.hash);
                if (repeat == 0) {
                    caseAggregate.reference = std::move(result);
                    allStepTimes.insert(allStepTimes.end(),
                        caseAggregate.reference.stepMicroseconds.begin(),
                        caseAggregate.reference.stepMicroseconds.end());
                } else if (result.hash != hashes.front() && caseAggregate.firstHashMismatch < 0) {
                    caseAggregate.firstHashMismatch = repeat;
                }
            }
            std::sort(hashes.begin(), hashes.end());
            caseAggregate.uniqueHashes = int(std::unique(hashes.begin(), hashes.end()) - hashes.begin());
            caseAggregate.repeats = kRepeatCount;
            caseAggregate.deterministic = caseAggregate.uniqueHashes == 1;
            caseAggregate.passed = CasePasses(spec, caseAggregate.reference,
                                              caseAggregate.deterministic);
            configAggregate.passed = configAggregate.passed && caseAggregate.passed;
            configAggregate.cases.push_back(std::move(caseAggregate));
        }
        aggregates.push_back(std::move(configAggregate));
    }

    rusage usageEnd {};
    getrusage(RUSAGE_SELF, &usageEnd);
    const auto wallEnd = std::chrono::steady_clock::now();
    const double wallSeconds = std::chrono::duration<double>(wallEnd - wallStart).count();
    const double userCPUSeconds = TimevalSeconds(usageEnd.ru_utime) - TimevalSeconds(usageStart.ru_utime);
    const double systemCPUSeconds = TimevalSeconds(usageEnd.ru_stime) - TimevalSeconds(usageStart.ru_stime);

    WriteJSON(argv[1], aggregates, allStepTimes, wallSeconds,
              userCPUSeconds, systemCPUSeconds);

    bool solverGreen = std::any_of(aggregates.begin(), aggregates.end(),
                                   [](const ConfigAggregate &value) { return value.passed; });
    std::cout << "solver=" << (solverGreen ? "GREEN" : "RED")
              << " production=RED"
              << " wall_seconds=" << std::fixed << std::setprecision(3) << wallSeconds
              << " p99_step_us=" << Percentile(allStepTimes, 0.99) << "\n";

    UnregisterTypes();
    delete Factory::sInstance;
    Factory::sInstance = nullptr;
    return solverGreen ? 0 : 1;
}
