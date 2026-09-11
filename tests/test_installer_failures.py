import io
import subprocess

from conjunction_gui.backend import InstallConfig, InstallationRunner


def test_real_install_cannot_fall_back_to_simulated_success(tmp_path, monkeypatch):
    results = []
    runner = InstallationRunner(InstallConfig(is_dry_run=False), on_complete=lambda *result: results.append(result))
    monkeypatch.setattr(runner, "_find_installer_script", lambda: None)
    monkeypatch.setattr(runner, "_find_bash", lambda: None)
    monkeypatch.setattr(runner, "_write_config_file", lambda: tmp_path / "config.json")
    runner._run()
    assert results and results[0][0] is False
    assert "no installation was performed" in results[0][1]


def test_failed_step_heading_does_not_create_completion_checkpoint(tmp_path, monkeypatch):
    results = []
    runner = InstallationRunner(InstallConfig(), on_complete=lambda *result: results.append(result))
    runner.state_file = tmp_path / "state.json"

    class FailedProcess:
        stdout = io.StringIO("═══ Step 4: Install Base System ═══\npackage installation failed\n")

        def wait(self):
            return 1

    monkeypatch.setattr(subprocess, "Popen", lambda *args, **kwargs: FailedProcess())
    runner._run_backend_script("bash", tmp_path / "installer.sh", tmp_path / "config.json")
    assert results == [(False, "Installation halted with exit code 1")]
    assert not runner.state_file.exists()


def test_simulation_uses_separate_checkpoint_file():
    actual = InstallationRunner(InstallConfig(is_dry_run=False))
    simulation = InstallationRunner(InstallConfig(is_dry_run=True))
    assert actual.state_file != simulation.state_file
