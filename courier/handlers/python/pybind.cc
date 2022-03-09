// Copyright 2020 DeepMind Technologies Limited.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <pybind11/pybind11.h>
#include <pybind11/pytypes.h>

#include <memory>

#include "absl/base/thread_annotations.h"
#include "absl/status/status.h"
#include "absl/status/statusor.h"
#include "absl/strings/string_view.h"
#include "absl/synchronization/mutex.h"
#include "absl/synchronization/notification.h"
#include "courier/handlers/interface.h"
#include "courier/handlers/py_call.h"

#include "courier/serialization/py_serialize.h"
#include "courier/serialization/pybind_serialize.h"
#include "courier/serialization/serialization.pb.h"
#include "pybind11_abseil/absl_casters.h"
#include "pybind11_abseil/status_casters.h"
#include "courier/platform/status_macros.h"

namespace courier {

namespace py = pybind11;


namespace {

std::shared_ptr<HandlerInterface> BuildPyCallHandlerWrapper(
    py::handle& handle) {
  PyObject* object = handle.ptr();
  return BuildPyCallHandler(object);
}


absl::StatusOr<pybind11::object> CallHandler(
    std::shared_ptr<HandlerInterface> handler, const std::string& method,
    const pybind11::list& args, const pybind11::dict& kwargs) {
  courier::CallArguments arguments;
  COURIER_RETURN_IF_ERROR(SerializePybindArgs(args, kwargs, &arguments));

  PyThreadState* thread_state = PyEval_SaveThread();
  COURIER_ASSIGN_OR_RETURN(auto result, handler->Call(method, arguments));
  PyEval_RestoreThread(thread_state);
  COURIER_ASSIGN_OR_RETURN(courier::SafePyObjectPtr py_object,
                           DeserializePyObject(result.result()));
  return pybind11::reinterpret_steal<pybind11::object>(py_object.release());
}

PYBIND11_MODULE(pybind, m) {
  py::google::ImportStatusModule();

  m.def("BuildPyCallHandler", &BuildPyCallHandlerWrapper);

  py::class_<HandlerInterface, std::shared_ptr<HandlerInterface>>(
      m, "HandlerInterface");

}

}  // namespace
}  // namespace courier
